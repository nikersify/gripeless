import {Elm} from '@gripeless/elm/source/Entry/App'
import gripeless from '@gripeless/sdk'

import defaultAvatarURL from '../../img/default-avatar.png'
import initAuth from '../auth'
import initFirebase from '../firebase'
import {assertDefined} from '../util'

if (typeof process.env.HOSTNAME !== 'string') {
	throw new TypeError('HOSTNAME not defined')
}

if (typeof process.env.STRIPE_PK !== 'string') {
	throw new TypeError('STRIPE_PK not defined')
}

const stripe = (() => {
	if (window.Stripe) {
		return Stripe(process.env.STRIPE_PK)
	}

	console.warn('Stripe is not defined')
})()

const demoProjectName = assertDefined(
	process.env.DEMO_PROJECT_NAME,
	'DEMO_PROJECT_NAME'
)

const gripelessProjectName = assertDefined(
	process.env.GRIPELESS_PROJECT_NAME,
	'GRIPELESS_PROJECT_NAME'
)

const supportEmail = assertDefined(
	process.env.SUPPORT_EMAIL,
	'SUPPORT_EMAIL'
)

const apiURL = assertDefined(process.env.API_URL, 'API_URL')
const sdkURL = assertDefined(process.env.SDK_URL, 'SDK_URL')

const app = Elm.Entry.App.init({
	flags: {
		demoProjectName,
		gripelessProjectName,
		host: process.env.HOSTNAME,
		device: {
			isDesktop: true, // TODO fix this sometime
			isMac: window.navigator.platform.indexOf('Mac') === 0
		},
		supportEmail,
		resources: {
			defaultAvatarURL
		},
		apiURL,
		sdkURL
	}
})

const fire = initFirebase()
const auth = initAuth(fire, () => app.ports.userUIDChanged.send)

app.ports.signIn.subscribe(auth.signIn(app.ports.signInError.send))
app.ports.signOut.subscribe(auth.signOut)
app.ports.prepareQuery.subscribe(async queryName => {
	const token = await auth.getIdToken()

	app.ports.queryPrepared.send({
		queryName,
		token
	})
})

app.ports.openGripeless.subscribe(([projectName, maybeMessage]) => {
	const email = auth.getEmail()
	gripeless.modal(projectName, {
		email: email === null ? undefined : email,
		message: maybeMessage || undefined
	})
})

app.ports.select.subscribe(id => {
	requestAnimationFrame(() => {
		const $input = document.getElementById(
			id
		) as HTMLInputElement | null

		if ($input) {
			$input.select()
		} else {
			console.error(`Input #${id} not found`)
		}
	})
})

app.ports.redirectToCheckout.subscribe(async sessionId => {
	if (!stripe) {
		throw new Error(
			'Stripe SDK must be loaded to perform this operation'
		)
	}

	try {
		await stripe.redirectToCheckout({sessionId})
	} catch (error) {
		console.error(error)

		app.ports.redirectToCheckoutError.send(
			error && typeof error.message === 'string'
				? error.message
				: 'Unknown error before redirecting to checkout'
		)
	}
})
