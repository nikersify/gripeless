import util from 'util'

import {
	ApolloServer,
	AuthenticationError,
	ForbiddenError,
	UserInputError,
	ValidationError,
	makeExecutableSchema
} from 'apollo-server-express'
import bodyParser from 'body-parser'
import cors from 'cors'
import express, {Express} from 'express'
import * as admin from 'firebase-admin'
import {isLeft} from 'fp-ts/lib/Either'
import helmet from 'helmet'
import imageType from 'image-type'
import multer from 'multer'
import * as postmark from 'postmark'
import {createPool, sql} from 'slonik'
import Stripe from 'stripe'

import * as helpers from './helpers'
import {makeLoaders} from './loaders'
import {assertRight, resolvers} from './resolvers'
import {Context, User} from './types/Context'
import {wrap} from './util'

export type Config = {
	pg: {
		database: string
		user: string
		password: string
		host: string
		port: number
	}
	schema: string
	// https://console.firebase.google.com/project/<project>/settings/serviceaccounts/adminsdk
	firebase: {
		projectId: string
		clientEmail: string
		privateKey: string
	}
	dev: boolean
	stripe: {
		publishableKey: string
		secretKey: string
		webhookSigningSecret: string
		plans: {
			growth: string
		}
	}
	postmark: {
		serverToken?: string
		from: string
		templates: {
			newGripe: string
			gripeFixed: string
		}
	}
	meta: {
		apiHostname: string
		dashboardHostname: string
		supportEmail: string
	}
}

export const makeApp = async (config: Config): Promise<Express> => {
	const db = createPool(
		`postgresql://${config.pg.user}@${config.pg.host}:${config.pg.port}/${config.pg.database}`
	)

	// https://console.firebase.google.com/project/<project>/settings/serviceaccounts/adminsdk
	const firebaseAdmin = admin.initializeApp({
		credential: admin.credential.cert(config.firebase)
	})

	const auth = firebaseAdmin.auth()

	const stripe = new Stripe(config.stripe.secretKey, {
		typescript: true,
		apiVersion: '2019-12-03'
	})

	const {serverToken} = config.postmark
	const postmarkServerClient = serverToken
		? new postmark.ServerClient(serverToken)
		: undefined

	const app = express()

	app.disable('x-powered-by')

	app.use(
		helmet({
			hsts: {
				maxAge: 31536000,
				preload: true
			}
		})
	)

	app.post(
		'/hooks/stripe',
		bodyParser.raw({type: 'application/json'}),
		wrap(async (req, res) => {
			const sig = req.headers['stripe-signature']

			let event
			try {
				event = stripe.webhooks.constructEvent(
					req.body,
					sig || '',
					config.stripe.webhookSigningSecret
				)
			} catch (error) {
				return res
					.status(400)
					.send(`Webhook error: ${error.message}`)
			}

			const eventId = event.id
			const loaders = makeLoaders(db)

			if (event.type === 'checkout.session.completed') {
				const session = event.data
					.object as Stripe.Checkout.Session

				if (typeof session.subscription !== 'string') {
					return res
						.status(500)
						.send('No subscription on session object')
				}

				if (session.client_reference_id === null) {
					return res
						.status(500)
						.send('No client_reference_id on session object')
				}

				const clientReferenceId = session.client_reference_id

				const projectEither = await loaders.projectById.load(
					session.client_reference_id
				)

				if (isLeft(projectEither)) {
					return res
						.status(500)
						.send(
							`Could not find project with an \`id\` of ${clientReferenceId}`
						)
				}

				// const subscription = await stripe.subscriptions.retrieve(
				// 	session.subscription
				// )

				const subscriptionValidUntil = new Date(
					// yolo and no time, we'll monitor for cancelled shit manually for now
					2021,
					0,
					1
					// subscription.current_period_end * 1000
				).toISOString()

				await db.transaction(async tx => {
					await tx.any(sql`
						update projects
						set subscription_valid_until = ${subscriptionValidUntil}
						where id = ${clientReferenceId}
					`)

					await tx.any(sql`
						insert into stripe_handled_events(id)
						values (${eventId})
					`)
				})
			}

			console.log('handled stripe event', event.type)

			res.json({received: true})
		})
	)

	const upload = multer({
		limits: {
			fileSize: 1024 * 1024 * 10 // 10MB
		}
	})

	app.get('/image/:name', cors(), async (req, res) => {
		const [id] = (req.params.name || '').split('.')
		let image
		try {
			image = await db.oneFirst(sql`
				select data from images
				where id = ${id}
			`)
		} catch {
			return res.status(404).send('Image not found')
		}

		res.end(image)
	})

	app.post(
		'/upload/image',
		cors(),
		upload.single('image'),
		wrap(async (req, res) => {
			const {file} = req

			const imgType = imageType(file.buffer)

			if (!imgType) {
				return res.status(400).send('Could not infer image type')
			}

			const allowedExtensions = ['jpg', 'png', 'tif', 'bmp', 'webp']

			if (!allowedExtensions.includes(imgType.ext)) {
				return res
					.status(400)
					.send(`This extension (${imgType.ext}) is not allowed`)
			}

			const id = await db.oneFirst(sql`
				insert into images (ext, data)
				values (${imgType.ext}, ${sql.binary(file.buffer)})
				returning id
			`)

			res.json({
				id,
				destination: `/image/${id}.${imgType.ext}`
			})
		})
	)

	const apollo = new ApolloServer({
		tracing: config.dev,
		debug: true,
		schema: makeExecutableSchema({
			typeDefs: config.schema,
			resolvers,
			resolverValidationOptions: {
				// Handled by graphql-code-generator's
				// `config.nonOptionalTypename = true` forcing us to always
				// specify a type name when returning a row at compile time.
				// The following simply disables a graphql warning.
				requireResolversForResolveType: false
			}
		}),
		formatError: error => {
			const blacklist = [
				UserInputError,
				AuthenticationError,
				ForbiddenError,
				ValidationError
			]

			if (
				!blacklist.some(
					b =>
						error instanceof b ||
						error.originalError instanceof b
				)
			) {
				// Log the specific error to console, but don't give it to
				// the client
				console.error(util.inspect(error, true, Infinity))

				return new Error('Internal server error')
			}

			return error
		},
		context: async ({req}): Promise<Context> => {
			const loaders = makeLoaders(db)

			if (config.dev) {
				await new Promise(resolve => setTimeout(resolve, 200))
			}

			const getUser = async (): Promise<User | undefined> => {
				const {authorization} = req.headers

				if (authorization === undefined || authorization === '') {
					return undefined
				}

				// Errors if token is invalid, just return undefined
				const decodedToken = await auth
					.verifyIdToken(authorization)
					.catch(() => undefined)

				if (decodedToken === undefined) {
					throw new AuthenticationError(
						'Could not decode `authorization` header token.'
					)
				}

				const {uid} = decodedToken

				const log = (...msgs: any[]) =>
					console.log(`(${uid})`, ...msgs)

				if (
					decodedToken.firebase.sign_in_provider === 'anonymous'
				) {
					return {
						isAnonymous: true,
						uid: uid
					}
				}

				const fetchFirebaseUserAndRegister = async () => {
					// "Register" the firebase user into our database, aka.
					// save their initial name, picture and email

					// Current problem with the auth flow is that you can
					// create a lot of anonymous users by signing in and out
					// repeatedly - we should purge anonymous users older
					// than x every once in a while.

					log('Registering user')

					const fbUser = await auth.getUser(uid)

					log(`firebase user data:`, fbUser)

					const userInfo = fbUser.providerData[0]
					if (!userInfo) {
						throw new Error(
							'Failed to fetch user information from auth providers'
						)
					}

					await db.transaction(async tx => {
						log(
							"Creating user in `users` table if doesn't exist"
						)

						await helpers.createUserIfNotExists(tx)(uid)

						log('Inserting users_data')
						await tx.any(sql`
							insert into users_data (uid, name, picture, email)
							values (
								${uid},
								${userInfo.displayName || userInfo.email},
								${userInfo.photoURL || null},
								${userInfo.email}
							)
						`)
					})

					const user = assertRight(
						await loaders.user.clear(uid).load(uid)
					)

					if (user.is_anonymous) {
						throw new Error(
							'Failed to insert initial user data'
						)
					}

					return user
				}

				const eUser = await loaders.user.load(uid)

				if (isLeft(eUser) && eUser.left.kind === 'server') {
					throw eUser.left.error
				}

				const user =
					isLeft(eUser) || eUser.right.is_anonymous
						? await fetchFirebaseUserAndRegister()
						: eUser.right

				log('User loaded')

				return {
					isAnonymous: false,
					uid: user.uid,
					name: user.name,
					picture: user.picture,
					email: user.email,
					stripeCustomerId:
						user.stripe_customer_id === null
							? undefined
							: user.stripe_customer_id
				}
			}

			const user = await getUser()

			return {
				db,
				loaders,
				user,
				billing: {
					stripe,
					plans: config.stripe.plans
				},
				meta: config.meta,
				connection: {
					userAgent: req.get('User-Agent')
				},
				postmark: {
					client: postmarkServerClient,
					...config.postmark
				}
			}
		}
	})

	apollo.applyMiddleware({
		app,
		cors: {
			maxAge: 86400
		},
		path: '/'
	})

	return app
}
