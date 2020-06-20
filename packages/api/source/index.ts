import fs from 'fs'

import {schemaPath} from '@gripeless/schema'

import {makeApp} from './app'
import {getEnv} from './env'

const env = getEnv()

export const main = async () => {
	const app = await makeApp({
		pg: {
			database: env.PGDATABASE,
			user: env.PGUSER,
			password: env.PGPASSWORD,
			host: env.PGHOST,
			port: 5432
		},
		schema: fs.readFileSync(schemaPath, 'utf8'),
		firebase: {
			projectId: env.FIREBASE_PROJECT_ID,
			clientEmail: env.FIREBASE_CLIENT_EMAIL,
			privateKey: env.FIREBASE_PRIVATE_KEY
		},
		stripe: {
			publishableKey: env.STRIPE_PK,
			secretKey: env.STRIPE_SK,
			webhookSigningSecret: env.STRIPE_WEBHOOK_SIGNING_SECRET,
			plans: {
				growth: env.STRIPE_GROWTH_PLAN_ID
			}
		},
		meta: {
			apiHostname: env.API_HOSTNAME,
			dashboardHostname: env.DASHBOARD_HOSTNAME,
			supportEmail: env.SUPPORT_EMAIL
		},
		postmark: {
			serverToken: env.POSTMARK_SERVER_TOKEN,
			from: env.POSTMARK_FROM,
			templates: {
				newGripe: env.POSTMARK_NEW_GRIPE_TEMPLATE,
				gripeFixed: env.POSTMARK_GRIPE_FIXED_TEMPLATE
			}
		},
		dev: (process.env.NODE_ENV || '').toLowerCase() !== 'production'
	})

	const port = env.PORT

	const host = process.argv[2] === '--expose' ? '0.0.0.0' : '127.0.0.1'
	app.listen(port, host, () => {
		console.log(`Server listening on port ${port}`)
	})
}

main().catch(error => {
	console.error(error)
	process.exit(1)
})
