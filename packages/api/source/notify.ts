import {isLeft} from 'fp-ts/lib/Either'
import {TemplatedMessage} from 'postmark'

import {Context} from './types/Context'

const makeNotifyLog = (notificationType: string, projectName: string) => (
	...msgs: any[]
) =>
	console.log(
		'[notify]',
		`[${notificationType}]`,
		`[${projectName}]`,
		...msgs
	)

export const newGripe = async (
	context: Context,
	args: {
		project: {
			name: string
			ownerUid: string
		}
		gripe: {
			id: string
			body: string
			imageId: string | null
		}
	}
) => {
	const log = makeNotifyLog('new-gripe', args.project.name)
	const {client} = context.postmark

	if (client === undefined) {
		log('No postmark client provided, skipping notification')

		return
	}

	if (args.project.name === 'demo') {
		log('gripe on `demo` project, not sending notification')

		return
	}

	const projectOwnerE = await context.loaders.user.load(
		args.project.ownerUid
	)

	if (isLeft(projectOwnerE) || projectOwnerE.right.is_anonymous) {
		log(`Project owner is anonymous. Not sending notification.`)

		return
	}

	const projectOwner = projectOwnerE.right
	const to = projectOwner.email

	log(`Sending new gripe notification to ${to}`)

	const message = new TemplatedMessage(
		context.postmark.from,
		context.postmark.templates.newGripe,
		{
			username: projectOwner.name,
			projectName: args.project.name,
			gripe: {
				body: args.gripe.body,
				image: args.gripe.imageId
					? {
							url: `https://${context.meta.apiHostname}/image/${args.gripe.imageId}`
					  }
					: false,
				url: `https://${context.meta.dashboardHostname}/app/dashboard/${args.project.name}/gripes?gripe=${args.gripe.id}`
			}
		},
		to
	)

	await client.sendEmailWithTemplate(message)
	log('Notification sent!')
}

export const gripeCompleted = async (
	context: Context,
	args: {
		to: string | null
		project: {
			name: string
		}
		gripe: {
			body: string
			title: string
		}
	}
) => {
	const log = makeNotifyLog('gripe-completed', args.project.name)
	const {client} = context.postmark

	if (client === undefined) {
		log('No postmark client provided, skipping notification')

		return
	}

	if (args.to === null) {
		log('Gripe creator did not provide email, skipping notification')

		return
	}

	const message = new TemplatedMessage(
		context.postmark.from,
		context.postmark.templates.gripeFixed,
		{
			gripe: {
				body: args.gripe.body,
				title: args.gripe.title
			},
			projectName: args.project.name
		},
		args.to
	)

	await client.sendEmailWithTemplate(message)
	log('Notification sent!')
}
