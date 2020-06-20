import {Elm} from '@gripeless/elm/source/Entry/BlogMailing'
import gripeless from '@gripeless/sdk'

import initFirebase from '../firebase'
import {assertDefined} from '../util'

const apiURL = assertDefined(process.env.API_URL, 'API_URL')

const gripelessProjectName = assertDefined(
	process.env.GRIPELESS_PROJECT_NAME,
	'GRIPELESS_PROJECT_NAME'
)

const $button = document.querySelector('#gripeless-button')

if ($button) {
	$button.addEventListener('click', () =>
		gripeless.modal(gripelessProjectName)
	)
} else {
	console.error('Failed to find Gripeless button')
}

initFirebase()

document.querySelectorAll('.mailing-form-entry').forEach($node =>
	Elm.Entry.BlogMailing.init({
		node: $node as HTMLElement,
		flags: apiURL
	})
)
