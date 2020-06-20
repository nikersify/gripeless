import {Elm} from '@gripeless/elm/source/Entry/Docs'
import gripeless from '@gripeless/sdk'

import logotypeURL from '../../img/logotype.svg'
import initFirebase from '../firebase'
import {assertDefined} from '../util'

const gripelessProjectName = assertDefined(
	process.env.GRIPELESS_PROJECT_NAME,
	'GRIPELESS_PROJECT_NAME'
)

const demoProjectName = assertDefined(
	process.env.DEMO_PROJECT_NAME,
	'DEMO_PROJECT_NAME'
)

const sdkURL = assertDefined(process.env.SDK_URL, 'SDK_URL')

const supportEmail = assertDefined(
	process.env.SUPPORT_EMAIL,
	'SUPPORT_EMAIL'
)

const app = Elm.Entry.Docs.init({
	flags: {
		projectName: gripelessProjectName,
		demoProjectName,
		sdkURL,
		supportEmail,
		logotypeURL
	}
})

app.ports.openGripeless.subscribe(([projectName, message]) =>
	gripeless.modal(projectName, {
		isDemo: projectName === demoProjectName,
		message: message || undefined
	})
)

initFirebase()
