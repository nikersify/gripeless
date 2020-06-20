import {ServerClient} from 'postmark'
import {DatabasePoolType} from 'slonik'
import Stripe from 'stripe'

import {Loaders} from '../loaders'

export type AnonymousUser = {
	isAnonymous: true
	uid: string
}

export type NonAnonymousUser = {
	isAnonymous: false
	uid: string
	email: string
	name: string
	picture: string
	stripeCustomerId?: string
}

export type User = AnonymousUser | NonAnonymousUser

export type Context = {
	db: DatabasePoolType
	loaders: Loaders
	user?: User
	billing: {
		stripe: Stripe
		plans: {
			growth: string
		}
	}
	meta: {
		apiHostname: string
		dashboardHostname: string
		supportEmail: string
	}
	connection: {
		userAgent?: string
	}
	postmark: {
		client?: ServerClient
		from: string
		templates: {
			newGripe: string
			gripeFixed: string
		}
	}
}
