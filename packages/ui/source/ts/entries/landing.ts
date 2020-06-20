import {Elm as ElmLanding} from '@gripeless/elm/source/Entry/LandingElement'
import {Elm as ElmReminderMailing} from '@gripeless/elm/source/Entry/ReminderMailing'
import gripeless from '@gripeless/sdk'

import initAuth from '../auth'
import {addCrisp} from '../crisp'
import initFirebase from '../firebase'
import {shakyMessages} from '../shaky'
import {assertDefined} from '../util'

// Elm app
const demoProjectName = assertDefined(
	process.env.DEMO_PROJECT_NAME,
	'DEMO_PROJECT_NAME'
)

const gripelessProjectName = assertDefined(
	process.env.GRIPELESS_PROJECT_NAME,
	'GRIPELESS_PROJECT_NAME'
)

const apiURL = assertDefined(process.env.API_URL, 'API_URL')

const app = ElmLanding.Entry.LandingElement.init({
	node: document.getElementById('app'),
	flags: {apiURL}
})

const fire = initFirebase()
const auth = initAuth(fire, () => app.ports.userUIDChanged.send)

app.ports.signOut.subscribe(auth.signOut)
app.ports.prepareQuery.subscribe(async queryName => {
	const token = await auth.getIdToken()

	app.ports.queryPrepared.send({
		queryName,
		token
	})
})

const registerGripelessButton = (
	selector: string,
	projectName: string,
	isDemo: boolean
) => {
	const $buttons = document.querySelectorAll(selector)

	$buttons.forEach($button =>
		$button.addEventListener('click', () =>
			gripeless.modal(projectName, {isDemo})
		)
	)
}

registerGripelessButton('#gripeless-button', gripelessProjectName, false)
registerGripelessButton('#demo-gripeless-button', demoProjectName, true)
shakyMessages('#shaky-messages')
addCrisp()

document.querySelectorAll('.mailing-reminder-entry').forEach($node =>
	ElmReminderMailing.Entry.ReminderMailing.init({
		node: $node as HTMLElement,
		flags: apiURL
	})
)
