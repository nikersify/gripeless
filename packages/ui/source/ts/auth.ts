import 'firebase/auth'

import firebase from 'firebase/app'

import {Thunk, noop} from './util'

export const providers = {
	Google: new firebase.auth.GoogleAuthProvider(),
	GitHub: new firebase.auth.GithubAuthProvider()
}

export type ProviderNames = keyof typeof providers

export function isProviderName(x: string): x is ProviderNames {
	return Object.keys(providers).includes(x)
}

type StringCallback = (string: string) => void

type UserUID = string
type IsAnonymous = boolean

export default (
	fire: firebase.app.App,
	onUserUIDChangedCallbackThunk: Thunk<
		(data: [UserUID, IsAnonymous] | null) => any
	> = () => noop
) => {
	// auth: fire.auth(),
	const auth = fire.auth()
	let initialising = true

	auth.onAuthStateChanged(async user => {
		if (!user) {
			// Loading
			onUserUIDChangedCallbackThunk()(null)

			// Make sure that auth.currentUser is never null by having
			// always signing in anonymously in the background
			return auth
				.signInAnonymously()
				.catch(error => console.error(error))
		}

		initialising = false

		onUserUIDChangedCallbackThunk()([user.uid, user.isAnonymous])
	})

	return {
		signIn: (onError: StringCallback) => async (
			providerName: string
		) => {
			if (!isProviderName(providerName)) {
				throw new Error(
					`Invalid auth provider name: ${providerName}`
				)
			}

			const provider = providers[providerName]

			const {currentUser} = auth
			if (currentUser === null) {
				return onError('Could not find anonymous user to upgrade')
			}

			if (!currentUser.isAnonymous) {
				return onError(
					`User already logged in (email: ${currentUser.email})`
				)
			}

			// Start loading
			onUserUIDChangedCallbackThunk()(null)

			try {
				// await auth.signInWithPopup(providers[providerName])
				try {
					const credentials = await currentUser.linkWithPopup(
						providers[providerName]
					)
				} catch (e) {
					const error = e as firebase.FirebaseError & {
						credential?: firebase.auth.AuthCredential
					}

					if (error.code === 'auth/credential-already-in-use') {
						const credential = error.credential as firebase.auth.AuthCredential
						await auth.signInWithCredential(credential)
					} else {
						throw error
					}
				}

				onUserUIDChangedCallbackThunk()([currentUser.uid, false])
			} catch (error) {
				onError(
					error.message ||
						'Something went wrong during authentication'
				)

				console.error(error)
			}
		},
		signOut: () => auth.signOut(),
		getIdToken: async () => {
			if (initialising) {
				await new Promise(resolve => {
					const unsubscribe = auth.onIdTokenChanged(() => {
						unsubscribe()
						resolve()
					})
				})
			}

			const user = auth.currentUser
			return user === null ? null : await user.getIdToken()
		},
		getEmail: () => (auth.currentUser ? auth.currentUser.email : null)
	}
}
