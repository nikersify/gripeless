import * as t from 'io-ts'

import {nullable} from '../util'

// These types correspond to whatever the database returns
export const User = t.intersection([
	t.type({
		uid: t.string,
		created_at: t.number
	}),
	t.union([
		t.type({
			is_anonymous: t.literal(true)
		}),
		t.type({
			is_anonymous: t.literal(false),
			email: t.string,
			name: t.string,
			picture: t.string,
			stripe_customer_id: nullable(t.string),
			data_created_at: t.number
		})
	])
])

export const OnboardingStep = t.keyof({
	'report-gripe': null,
	'title-gripe': null,
	'take-action-on-gripe': null,
	'sign-in': null,
	install: null,
	'have-fun': null,
	done: null
})

export const Project = t.type(
	{
		id: t.string,
		name: t.string,
		owner_uid: t.string,
		subscription_valid_until: nullable(t.number),
		onboarding_step: OnboardingStep,
		created_at: t.number
	},
	'Project'
)

export const GripeStatus = t.keyof({
	open: null,
	completed: null,
	discarded: null
})

export const devicePlatforms = {
	desktop: null,
	mobile: null,
	tablet: null,
	tv: null
}

export const DevicePlatform = t.keyof(devicePlatforms)

export const GripeComment = t.type({
	id: t.string,
	author_uid: nullable(t.string),
	body: t.string,
	created_at: t.number
})

export const Gripe = t.type(
	{
		id: t.string,
		title: nullable(t.string),
		status: GripeStatus,
		project_id: t.string,
		body: t.string,
		context: t.string,
		notify_email: nullable(t.string),
		image_id: nullable(t.string),
		device_user_agent: nullable(t.string),
		device_viewport_size: nullable(t.string),
		device_url: nullable(t.string),
		device_browser: nullable(t.string),
		device_engine: nullable(t.string),
		device_os: nullable(t.string),
		device_platform: nullable(DevicePlatform),
		created_at: t.number,
		updated_at: nullable(t.number)
	},
	'Gripe'
)

export const GripeStatusEvent = t.intersection([
	t.type({
		id: t.number,
		created_at: t.number
	}),
	t.union([
		t.type({
			event: t.literal('update-title'),
			data: t.string
		}),
		t.type({
			event: t.keyof({
				discard: null,
				restore: null,
				complete: null
			}),
			data: t.null
		})
	])
])

export const GripeStatusEventIds = t.type({
	gripe_id: t.string,
	ids: t.array(t.number)
})

export type User = t.TypeOf<typeof User>
export type Project = t.TypeOf<typeof Project>
export type Gripe = t.TypeOf<typeof Gripe>
export type GripeComment = t.TypeOf<typeof GripeComment>
export type GripeStatus = t.TypeOf<typeof GripeStatus>
export type GripeStatusEvent = t.TypeOf<typeof GripeStatusEvent>
export type GripeStatusEventIds = t.TypeOf<typeof GripeStatusEventIds>
