import fs from 'fs'
import path from 'path'

import dotenv from 'dotenv'
import * as t from 'io-ts'
import {NonEmptyString} from 'io-ts-types/lib/NonEmptyString'
import {NumberFromString} from 'io-ts-types/lib/NumberFromString'

import {parseOrThrow} from './util'

export const getEnv = () =>
	parseOrThrow(
		t.type({
			PORT: NumberFromString,
			SUPPORT_EMAIL: NonEmptyString,
			PGDATABASE: NonEmptyString,
			PGUSER: NonEmptyString,
			PGPASSWORD: t.string,
			PGHOST: NonEmptyString,
			STRIPE_PK: NonEmptyString,
			STRIPE_SK: NonEmptyString,
			STRIPE_GROWTH_PLAN_ID: NonEmptyString,
			STRIPE_WEBHOOK_SIGNING_SECRET: NonEmptyString,
			FIREBASE_PROJECT_ID: NonEmptyString,
			FIREBASE_CLIENT_EMAIL: NonEmptyString,
			FIREBASE_PRIVATE_KEY: NonEmptyString,
			API_HOSTNAME: NonEmptyString,
			DASHBOARD_HOSTNAME: NonEmptyString,
			POSTMARK_SERVER_TOKEN: t.union([NonEmptyString, t.undefined]),
			POSTMARK_FROM: NonEmptyString,
			POSTMARK_NEW_GRIPE_TEMPLATE: NonEmptyString,
			POSTMARK_GRIPE_FIXED_TEMPLATE: NonEmptyString
		})
	)(
		(process.env.NODE_ENV || '').toLowerCase() === 'production'
			? process.env
			: dotenv.parse(
					fs.readFileSync(path.join(__dirname, '../.env'))
			  )
	)
