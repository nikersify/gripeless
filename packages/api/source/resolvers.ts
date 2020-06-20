import {ForbiddenError, UserInputError} from 'apollo-server-express'
import bowser from 'bowser'
import * as fp from 'fp-ts'
import {isRight} from 'fp-ts/lib/Either'
import {GraphQLScalarType} from 'graphql'
import {Kind} from 'graphql/language'
import * as t from 'io-ts'
import {sql} from 'slonik'
import uuid from 'uuid'

import {
	IGripeAction,
	IGripeStatus,
	IGripeTimelineItem,
	IOnboardingStep,
	IPosixTimeScalarConfig,
	IProjectRole,
	IResolvers
} from './generated/resolvers'
import * as generatedResolvers from './generated/resolvers'
import * as helpers from './helpers'
import * as hstore from './hstore'
import * as Loaders from './loaders'
import * as notify from './notify'
import {welcomeGripeText} from './resources'
import {Context, NonAnonymousUser, User} from './types/Context'
import * as loaderTypes from './types/loader-types'
import {nullable, parseOrThrow} from './util'

type LoaderError = Loaders.LoaderError

const {pipe} = fp.pipeable

export const unreachable: (x: never) => never = () => {
	throw new Error('Reached unreachable value')
}

export const assertStringLength = (min: number, max: number) => (
	label: string
) => (input: string) => {
	const length = input.length
	const err = (p: string, length: number) =>
		new UserInputError(
			`Expected ${label} to have ${p} length of ${length}, got ${length}`
		)

	if (length < min) {
		throw err('minimum', min)
	}

	if (length > max) {
		throw err('maximum', max)
	}

	return input
}

export const assertStringRegex = (regex: RegExp) => (label: string) => (
	input: string
) => {
	if (!regex.test(input)) {
		throw new UserInputError(
			`Expected ${label} to match ${regex.toString()}`
		)
	}

	return input
}

export const assertLoggedIn = (user?: Context['user']) => {
	if (user === undefined) {
		throw new ForbiddenError('User not logged in')
	}

	return user
}

export const assertNotAnonymousContextUser = (
	maybeUser: Context['user']
): NonAnonymousUser => {
	const user = assertLoggedIn(maybeUser)

	if (user.isAnonymous) {
		throw new Error(
			'You need a non-anonymous account to perform this action'
		)
	}

	return user
}

const assertNotAnonymousLoaderUser = (user: loaderTypes.User) => {
	if (user.is_anonymous) {
		throw new ForbiddenError(
			'You cannot access this field as an anonymous user'
		)
	}

	return user
}

export const assertRight = <E extends LoaderError, A>(
	ma: fp.either.Either<E extends LoaderError ? E : never, A>
) =>
	pipe(
		ma,
		fp.either.fold(
			error =>
				({
					input: () => {
						throw error.error as UserInputError
					},
					server: () => {
						throw new Error(
							(error.error as t.Errors).join('\n')
						)
					}
				}[error.kind]()),
			right => right
		)
	)

export const arrayAssertRight = <E extends LoaderError, A>(
	maArray: fp.either.Either<E extends LoaderError ? E : never, A>[]
) => fp.array.map(assertRight)(maArray)

export const assertOwnsProject = (msg: string) => (
	user: User,
	project: loaderTypes.Project
) => {
	if (user.uid !== project.owner_uid) {
		throw new ForbiddenError(msg)
	}
}

export const gripeStatusFilter = (status: IGripeStatus) =>
	({
		[IGripeStatus.New]: sql`gripes.title is null and gripes.status <> 'discarded'`,
		[IGripeStatus.Discarded]: sql`gripes.status = 'discarded'`,
		[IGripeStatus.Actionable]: sql`gripes.status = 'open' and gripes.title is not null`,
		[IGripeStatus.Done]: sql`gripes.status = 'completed'`
	}[status])

const userResolvers: IResolvers['User'] = {
	uid: p => p.uid,
	name: user => assertNotAnonymousLoaderUser(user).name,
	email: user => assertNotAnonymousLoaderUser(user).email,
	picture: user => assertNotAnonymousLoaderUser(user).picture
}

const gripeResolvers: IResolvers['Gripe'] = {
	id: p => p.id,

	status: gripe =>
		gripe.title === null && gripe.status !== 'discarded'
			? IGripeStatus.New
			: {
					open: IGripeStatus.Actionable,
					completed: IGripeStatus.Done,
					discarded: IGripeStatus.Discarded
			  }[gripe.status],

	title: p => p.title,
	body: p => p.body,
	imagePath: async (p, _, {db}) => {
		if (p.image_id === null) {
			return null
		}

		const ext = await db.oneFirst(sql`
			select ext
			from images where id = ${p.image_id}
		`)

		return `/image/${p.image_id}.${ext}`
	},
	context: p => hstore.parse(p.context),
	hasNotification: gripe => gripe.notify_email !== null,
	device: p => {
		const {IPlatform} = generatedResolvers
		return {
			__typename: 'Device' as const,
			url: p.device_url,
			userAgent: p.device_user_agent,
			viewportSize: p.device_viewport_size,
			browser: p.device_browser,
			engine: p.device_engine,
			os: p.device_os,
			platform:
				p.device_platform === null
					? null
					: {
							desktop: IPlatform.Desktop,
							mobile: IPlatform.Mobile,
							tablet: IPlatform.Tablet,
							tv: IPlatform.Tv
					  }[p.device_platform]
		}
	},
	created: p => new Date(p.created_at),
	updated: p => (p.updated_at === null ? null : new Date(p.updated_at)),
	timeline: async (gripe, _, context) => {
		const {ids: statusEventIds} = assertRight(
			await context.loaders.gripeStatusEventIdsByGripeIds.load(
				gripe.id
			)
		)

		const loadedGripeEvents = arrayAssertRight(
			await Promise.all(
				statusEventIds.map(id =>
					context.loaders.gripeStatusEvent.load(id)
				)
			)
		)

		const createdEvents = [
			{
				__typename: 'GripeCreatedEvent' as const,
				created: new Date(gripe.created_at)
			}
		]

		const otherEvents = loadedGripeEvents.map(gripeEvent => {
			if (gripeEvent.event === 'update-title') {
				return {
					__typename: 'GripeTitleUpdatedEvent' as const,
					created: new Date(gripeEvent.created_at),
					title: gripeEvent.data
				}
			} else {
				return {
					__typename: 'GripeStatusUpdatedEvent' as const,
					status: {
						discard: IGripeAction.Discard,
						restore: IGripeAction.Restore,
						complete: IGripeAction.Complete
					}[gripeEvent.event],
					created: new Date(gripeEvent.created_at)
				}
			}
		})

		const commentIds = parseOrThrow(
			t.array(t.string),
			Error
		)(
			await context.db.anyFirst(sql`
				select
					id
				from gripe_comments
				where gripe_id = ${gripe.id}
			`)
		)

		const comments = arrayAssertRight(
			await Promise.all(
				commentIds.map(id => context.loaders.gripeComment.load(id))
			)
		).map(c => ({
			__typename: 'GripeComment' as const,
			id: c.id,
			body: c.body,
			created: new Date(c.created_at)
		}))

		const base: IGripeTimelineItem[] = []

		return base
			.concat(createdEvents)
			.concat(otherEvents)
			.concat(comments)
			.sort((a, b) => {
				return a.created.getTime() - b.created.getTime()
			})
	}
}

const projectResolvers: IResolvers['Project'] = {
	id: p => p.id,
	name: p => p.name,

	role: (project, _, context) =>
		context.user === undefined ||
		project.owner_uid !== context.user.uid
			? IProjectRole.None
			: IProjectRole.Admin,

	plan: project => getProjectPlan(project),

	onboarding: (project, _, context) => {
		const user = assertLoggedIn(context.user)

		assertOwnsProject('You do not have permission to see onboarding')(
			user,
			project
		)

		return {
			'report-gripe': IOnboardingStep.ReportGripe,
			'title-gripe': IOnboardingStep.TitleGripe,
			'take-action-on-gripe': IOnboardingStep.TakeActionOnGripe,
			'sign-in': IOnboardingStep.SignIn,
			install: IOnboardingStep.Install,
			'have-fun': IOnboardingStep.HaveFun,
			done: IOnboardingStep.Done
		}[project.onboarding_step]
	},

	modalAppearance: project => {
		const isGrowthPlan =
			getProjectPlan(project).__typename === 'GrowthPlan'

		return {
			__typename: 'ModalAppearance' as const,
			hasBranding: !isGrowthPlan
		}
	}
}

const modalAppearanceResolvers: IResolvers['ModalAppearance'] = {
	hasBranding: p => p.hasBranding
}

const deviceResolvers: IResolvers['Device'] = {
	url: p => p.url,
	userAgent: p => p.userAgent,
	viewportSize: p => p.viewportSize,
	browser: p => p.browser,
	engine: p => p.engine,
	os: p => p.os,
	platform: p => p.platform
}

const checkoutSessionResolvers: IResolvers['CheckoutSession'] = {
	id: p => p.id
}

const projectNameAvailabilityResolvers: IResolvers['ProjectNameAvailability'] = {
	isAvailable: p => p.isAvailable,
	name: p => p.name
}

const planResolvers: IResolvers['Plan'] = {}

const freePlanResolvers: IResolvers['FreePlan'] = {
	since: p => p.since
}

const growthPlanResolvers: IResolvers['GrowthPlan'] = {
	since: p => p.since,
	nextBilling: p => p.nextBilling
}

const gripeEventResolvers: IResolvers['GripeEvent'] = {
	created: p => p.created
}

const gripeStatusUpdatedEventResolvers: IResolvers['GripeStatusUpdatedEvent'] = {
	created: p => p.created,
	status: p => p.status
}

const gripeTitleUpdatedEventResolvers: IResolvers['GripeTitleUpdatedEvent'] = {
	created: p => p.created,
	title: p => p.title
}

const gripeCreatedEventResolvers: IResolvers['GripeCreatedEvent'] = {
	created: p => p.created
}

const gripeCommentResolvers: IResolvers['GripeComment'] = {
	id: p => p.id,
	body: p => p.body,
	created: p => p.created
}

const getProjectPlan = (
	project: loaderTypes.Project
): generatedResolvers.IPlan =>
	project.subscription_valid_until === null
		? {
				__typename: 'FreePlan',
				since: new Date(project.created_at)
		  }
		: {
				__typename: 'GrowthPlan',
				since: new Date(project.created_at),
				nextBilling: new Date(project.subscription_valid_until)
		  }

export const resolvers: IResolvers = {
	// "Main" types
	User: userResolvers,
	Gripe: gripeResolvers,
	Project: projectResolvers,

	// "Subtypes"
	CheckoutSession: checkoutSessionResolvers,
	Device: deviceResolvers,
	ModalAppearance: modalAppearanceResolvers,
	ProjectNameAvailability: projectNameAvailabilityResolvers,

	// Plans
	Plan: planResolvers,
	FreePlan: freePlanResolvers,
	GrowthPlan: growthPlanResolvers,

	// Gripe comment
	GripeComment: gripeCommentResolvers,

	// Gripe event
	GripeEvent: gripeEventResolvers,
	GripeCreatedEvent: gripeCreatedEventResolvers,
	GripeStatusUpdatedEvent: gripeStatusUpdatedEventResolvers,
	GripeTitleUpdatedEvent: gripeTitleUpdatedEventResolvers,
	GripeTimelineItem: {},

	// Root types
	Query: {
		me: async (_, __, context) => {
			const {uid} = assertNotAnonymousContextUser(context.user)

			return assertRight(await context.loaders.user.load(uid))
		},
		project: async (_, args, context) => {
			return assertRight(
				await context.loaders.projectByName.load(args.name)
			)
		},
		gripe: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const gripe = assertRight(
				await context.loaders.gripe.load(args.id)
			)

			const project = assertRight(
				await context.loaders.projectById.load(gripe.project_id)
			)

			assertOwnsProject(
				'You do not have permission to view this gripe'
			)(user, project)

			return gripe
		},
		gripes: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const project = assertRight(
				await context.loaders.projectByName.load(args.projectName)
			)

			assertOwnsProject(
				'You do not have permission to access this project'
			)(user, project)

			const gripeIdsRaw = (await context.db.anyFirst(sql`
				select
					gripes.id
				from gripes_view gripes
				inner join projects on gripes.project_id = projects.id
				where projects.name = ${args.projectName}
				${args.status ? sql`and ${gripeStatusFilter(args.status)}` : sql``}
			`)) as unknown[]
			const gripeIds = parseOrThrow(t.array(t.string))(gripeIdsRaw)

			return arrayAssertRight(
				await Promise.all(
					gripeIds.map(id => context.loaders.gripe.load(id))
				)
			).sort(
				(a, b) =>
					(b.updated_at || b.created_at) -
					(a.updated_at || a.created_at)
			)
		},
		gripesCount: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const project = assertRight(
				await context.loaders.projectByName.load(args.projectName)
			)

			assertOwnsProject(
				'You do not have permission to access this project'
			)(user, project)

			const countRaw = await context.db.oneFirst(sql`
				select
					count(*)
				from gripes_view gripes
				inner join projects on gripes.project_id = projects.id
				where projects.name = ${args.projectName}
				${args.status ? sql`and ${gripeStatusFilter(args.status)}` : sql``}
			`)

			return parseOrThrow(t.number)(countRaw)
		},
		ownedProjects: async (_, __, context) => {
			const user = assertLoggedIn(context.user)

			const projectNames = (await context.db.any(sql`
				select name from projects where owner_uid = ${user.uid}
			`)) as unknown[]

			const decoded = parseOrThrow(
				t.array(t.type({name: t.string}))
			)(projectNames)

			const projects = await Promise.all(
				decoded.map(({name}) =>
					context.loaders.projectByName.load(name)
				)
			)

			return arrayAssertRight(projects)
		},
		isProjectNameAvailable: async (_, args, context) => {
			const {name} = args

			const project = await context.loaders.projectByName.load(name)

			const isIt = (b: boolean) => ({
				__typename: 'ProjectNameAvailability' as const,
				name,
				isAvailable: b
			})

			if (isRight(project)) {
				return isIt(false)
			} else {
				// Assert it's not a server error
				if (project.left.kind === 'server') {
					throw new Error(project.left.error.join('\n'))
				}

				return isIt(true)
			}
		}
	},
	Mutation: {
		createGripe: async (_, args, context) => {
			const project = assertRight(
				await context.loaders.projectByName.load(args.projectName)
			)

			const plan = getProjectPlan(project)

			const results = bowser.parse(
				context.connection.userAgent || ''
			)

			const versionOnlyWhenNameOrNull = (x: {
				name?: string
				version?: string
			}): string | null => {
				return x.name
					? x.name + (x.version ? ` ${x.version}` : ' ')
					: null
			}

			const device = {
				userAgent: context.connection.userAgent || null,
				url: args.gripe.url || null,
				viewportSize: args.gripe.viewportSize || null,
				browser: versionOnlyWhenNameOrNull(results.browser),
				engine: versionOnlyWhenNameOrNull(results.engine),
				os: versionOnlyWhenNameOrNull(results.os),
				platform:
					results.platform.type &&
					Object.keys(loaderTypes.devicePlatforms).includes(
						results.platform.type
					)
						? results.platform.type
						: null
			}

			const {imageId} = args.gripe

			if (imageId) {
				try {
					context.db.query(
						sql`select id from images where id = ${args.gripe.imageId}`
					)
				} catch {
					throw new UserInputError(
						'Image with the given id does not exist'
					)
				}
			}

			const id = uuid()

			const {gripe} = args
			const body = assertStringLength(1, 65536)('body')(gripe.body)

			// Ensure that notify email is not empty, otherwise just
			// default to null
			const notifyEmail =
				typeof args.gripe.notifyEmail === 'string' &&
				args.gripe.notifyEmail.length > 0
					? args.gripe.notifyEmail
					: null

			await context.db.query(sql`
				insert into gripes (
					id,
					project_id,
					body,
					image_id,
					context,
					notify_email,
					device_url,
					device_user_agent,
					device_viewport_size,
					device_browser,
					device_engine,
					device_os,
					device_platform
				)
				values (
					${id},
					${project.id},
					${body},
					${imageId},
					${hstore.stringify(args.gripe.context)},
					${notifyEmail},
					${device.url},
					${device.userAgent},
					${device.viewportSize},
					${device.browser},
					${device.engine},
					${device.os},
					${device.platform}
				)
			`)

			// Send notification email asynchronously
			process.nextTick(() =>
				notify.newGripe(context, {
					project: {
						name: project.name,
						ownerUid: project.owner_uid
					},
					gripe: {
						id,
						body,
						imageId
					}
				})
			)

			return assertRight(await context.loaders.gripe.load(id))
		},
		updateGripeTitle: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const gripe = assertRight(
				await context.loaders.gripe.load(args.id)
			)

			const project = assertRight(
				await context.loaders.projectById.load(gripe.project_id)
			)

			assertOwnsProject(
				'You do not have permission to edit this gripe'
			)(user, project)

			if (gripe.status !== 'open') {
				throw new UserInputError(
					'Cannot update title of a gripe of status other than `open`'
				)
			}

			const title = assertStringLength(1, 64)('title')(args.title)

			await context.db.any(sql`
				insert into gripe_events(gripe_id, event)
				values (${gripe.id}, row('update-title', ${title}))
			`)

			context.loaders.gripe.clear(gripe.id)

			return assertRight(await context.loaders.gripe.load(gripe.id))
		},
		createGripeComment: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const gripe = assertRight(
				await context.loaders.gripe.load(args.gripeId)
			)

			const project = assertRight(
				await context.loaders.projectById.load(gripe.project_id)
			)

			assertOwnsProject(
				"You can't create comments on gripes belonging to projects you don't have access to"
			)(user, project)

			const body = assertStringLength(1, 524288)('body')(args.body)

			await context.db.any(sql`
				insert into gripe_comments (gripe_id, author_uid, body)
				values (${gripe.id}, ${user.uid}, ${body})
			`)

			return gripe
		},
		completeGripe: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const gripe = assertRight(
				await context.loaders.gripe.load(args.id)
			)

			const project = assertRight(
				await context.loaders.projectById.load(gripe.project_id)
			)

			assertOwnsProject(
				'You do not have permission to complete this gripe'
			)(user, project)

			if (gripe.status !== 'open') {
				throw new UserInputError(
					'Cannot complete a gripe with status other than `open`'
				)
			}

			if (gripe.title === null) {
				throw new UserInputError(
					'Cannot complete a gripe without a title'
				)
			}

			await context.db.any(sql`
				insert into gripe_events(gripe_id, event)
				values (${gripe.id}, row('complete', null))
			`)

			process.nextTick(() => {
				if (gripe.title === null) {
					throw new TypeError(
						`Data inconsistency - completed gripe's title is null (id: ${gripe.id})`
					)
				}

				notify.gripeCompleted(context, {
					to: gripe.notify_email,
					project: {name: project.name},
					gripe: {
						body: gripe.body,
						title: gripe.title
					}
				})
			})

			return assertRight(
				await context.loaders.gripe.clear(gripe.id).load(gripe.id)
			)
		},
		discardGripe: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const gripe = assertRight(
				await context.loaders.gripe.load(args.id)
			)

			const project = assertRight(
				await context.loaders.projectById.load(gripe.project_id)
			)

			assertOwnsProject(
				'You do not have permission to discard this gripe'
			)(user, project)

			if (gripe.status !== 'open') {
				throw new UserInputError(
					'Cannot discard a gripe with status other than `open`'
				)
			}

			await context.db.any(sql`
				insert into gripe_events(gripe_id, event)
				values (${gripe.id}, row('discard', null))
			`)

			context.loaders.gripe.clear(gripe.id)

			return assertRight(await context.loaders.gripe.load(args.id))
		},
		restoreGripe: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const gripe = assertRight(
				await context.loaders.gripe.load(args.id)
			)

			const project = assertRight(
				await context.loaders.projectById.load(gripe.project_id)
			)

			assertOwnsProject(
				'You do not have permission to restore this gripe'
			)(user, project)

			if (gripe.status !== 'discarded') {
				throw new UserInputError(
					'Cannot restore a gripe with status other than `discarded`'
				)
			}

			await context.db.any(sql`
				insert into gripe_events(gripe_id, event)
				values (${gripe.id}, row('restore', null))
			`)

			context.loaders.gripe.clear(gripe.id)

			return assertRight(await context.loaders.gripe.load(gripe.id))
		},
		createProject: async (_, args, context) => {
			const user = assertLoggedIn(context.user)

			const existingProject = await context.loaders.projectByName.load(
				args.projectName
			)

			const exists =
				fp.either.isLeft(existingProject) &&
				existingProject.left.kind === 'input'

			if (!exists) {
				throw new UserInputError(
					'Project with the given name already exists'
				)
			}

			const name = assertStringRegex(
				// fyi this regex is copied to the client
				/^([a-z0-9][a-z0-9-]{1,30}[a-z0-9])$/
			)('name')(args.projectName)

			const projectID = uuid()

			if (user.isAnonymous) {
				await helpers.createUserIfNotExists(context.db)(user.uid)
			}

			await context.db.transaction(async t => {
				await t.query(sql`
					insert into projects (id, name, owner_uid)
					values (${projectID}, ${name}, ${user.uid})
				`)

				const text = welcomeGripeText(context.meta.supportEmail)
				await t.query(sql`
					insert into gripes (id, project_id, body)
					values (${uuid()}, ${projectID}, ${text})
				`)
			})

			return assertRight(
				await context.loaders.projectByName.clear(name).load(name)
			)
		},
		claimProject: async (_, {key}, context) => {
			// If the provided key matches a key attached onto any project
			// in the database:
			// 1. Clear out the key from the project
			// 2. Set the project's owner_uid to user's
			// 3. Set onboarding_done to true, since the prospect already
			//    somewhat knows what the product is about

			const user = assertLoggedIn(context.user)

			const projectId = parseOrThrow(
				nullable(t.string),
				TypeError
			)(
				await context.db.maybeOneFirst(sql`
					select id from projects where claim_key = ${key}
				`)
			)

			if (projectId === null) {
				throw new UserInputError('Invalid project claim key')
			}

			if (user.isAnonymous) {
				await helpers.createUserIfNotExists(context.db)(user.uid)
			}

			await context.db.any(sql`
				update projects set
					claim_key = null,
					owner_uid = ${user.uid},
					onboarding_done = true
				where id = ${projectId}
			`)

			return assertRight(
				await context.loaders.projectById.load(projectId)
			)
		},
		createCheckoutSession: async (_, args, context) => {
			const user = assertNotAnonymousContextUser(context.user)

			const project = assertRight(
				await context.loaders.projectByName.load(args.projectName)
			)

			assertOwnsProject(
				'You do not have permission to create a checkout session for this project'
			)(user, project)

			const plan = getProjectPlan(project)

			if (plan.__typename === 'GrowthPlan') {
				throw new UserInputError(
					'Cannot create a new subscription, you are already subscribed'
				)
			}

			// Create a new customer ID if one doesn't exist already

			const stripeCustomerId: string = await (async () => {
				if (user.stripeCustomerId === undefined) {
					const customer = await context.billing.stripe.customers.create(
						{
							email: user.email,
							name: user.name
						}
					)

					await context.db.any(sql`
						update users_data
						set stripe_customer_id = ${customer.id}
						where uid = ${user.uid}
					`)

					return customer.id
				}

				return user.stripeCustomerId
			})()

			const {
				id
			} = await context.billing.stripe.checkout.sessions.create({
				customer: stripeCustomerId,
				payment_method_types: ['card'],
				client_reference_id: project.id,
				subscription_data: {
					items: [
						{
							plan: context.billing.plans.growth
						}
					]
				},
				success_url: args.successUrl,
				cancel_url: args.cancelUrl
			})

			return {
				__typename: 'CheckoutSession' as const,
				id
			}
		},
		finishOnboarding: async (_, {projectName}, context) => {
			const user = assertLoggedIn(context.user)
			const project = assertRight(
				await context.loaders.projectByName.load(projectName)
			)

			assertOwnsProject(
				"Cannot finish onboarding for a project you don't own"
			)(user, project)

			await context.db.query(sql`
				update projects
					set onboarding_done = true
				where name = ${projectName}
			`)

			return assertRight(
				await context.loaders.projectByName
					.clear(projectName)
					.load(projectName)
			)
		},
		subscribeToBlogMailingList: async (_, {email}, {db}) => {
			await db.any(sql`
				insert into blog_emails (email) values (${email})
				on conflict do nothing
			`)

			return email
		},
		subscribeToReminderMailingList: async (_, {email}, {db}) => {
			await db.any(sql`
				insert into remind_emails (email) values (${email})
				on conflict do nothing
			`)

			return email
		}
	},

	// Custom scalars
	PosixTime: new GraphQLScalarType({
		name: 'PosixTime',
		description: 'POSIX Time, but with milliseconds',
		serialize: value => {
			if (!(value instanceof Date)) {
				throw new Error(`Could not serialize ${value}, not a Date`)
			}

			return value.getTime()
		},
		parseValue: passed => {
			const value = parseOrThrow(t.number, UserInputError)(passed)
			return new Date(value)
		},
		parseLiteral: ast => {
			if (ast.kind === Kind.INT) {
				return new Date(ast.value)
			}

			return null
		}
	} as IPosixTimeScalarConfig),
	GripeID: new GraphQLScalarType({
		name: 'GripeID',
		description: 'Gripe ID',
		serialize: value => {
			if (!(typeof value === 'string')) {
				throw new Error(
					`Could not serialize ${value}, not a string`
				)
			}

			return value
		}
	} as generatedResolvers.IGripeIdScalarConfig),
	KeyValueString: new GraphQLScalarType({
		name: 'KeyValueString',
		description: 'Object with string keys and string values',
		parseValue: raw => {
			// Expecting JSON [string, string][]

			return parseOrThrow(
				t.tuple([t.string, t.string]),
				UserInputError
			)(raw)
		}
	} as generatedResolvers.IKeyValueStringScalarConfig)
}
