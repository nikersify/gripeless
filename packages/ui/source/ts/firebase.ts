import 'firebase/analytics'

import * as firebase from 'firebase/app'

import {assertDefined as ad} from './util'

const apiKey = ad(process.env.FIREBASE_API_KEY, 'FIREBASE_API_KEY')
const authDomain = ad(
	process.env.FIREBASE_AUTH_DOMAIN,
	'FIREBASE_AUTH_DOMAIN'
)

const databaseURL = ad(
	process.env.FIREBASE_DATABASE_URL,
	'FIREBASE_DATABASE_URL'
)

const projectId = ad(
	process.env.FIREBASE_PROJECT_ID,
	'FIREBASE_PROJECT_ID'
)

const storageBucket = ad(
	process.env.FIREBASE_STORAGE_BUCKET,
	'FIREBASE_STORAGE_BUCKET'
)

const messagingSenderId = ad(
	process.env.FIREBASE_MESSAGING_SENDER_ID,
	'FIREBASE_MESSAGING_SENDER_ID'
)

const measurementId = ad(
	process.env.FIREBASE_MEASUREMENT_ID,
	'FIREBASE_MEASUREMENT_ID'
)

const appId = ad(process.env.FIREBASE_APP_ID, 'FIREBASE_APP_ID')

const init = () => {
	const fire = firebase.initializeApp({
		apiKey,
		authDomain,
		databaseURL,
		projectId,
		storageBucket,
		messagingSenderId,
		appId,
		measurementId
	})

	firebase.analytics(fire)

	return fire
}

export default init
