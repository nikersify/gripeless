import {promises as fs} from 'fs'
import http from 'http'
import https from 'https'

import del from 'del'
import fg from 'fast-glob'
import {series} from 'gulp'
import Bundler from 'parcel-bundler'

import makeApp from './server'

const isEnvDev =
	(process.env.NODE_ENV || '').toLowerCase() !== 'production'

const assertEnv = (key: string, inDev: string): string => {
	const value = process.env[key]

	if (value === undefined) {
		if (isEnvDev) {
			process.env[key] = inDev

			return inDev
		} else {
			throw new Error(`process.env.${key} is not defined`)
		}
	}

	return value
}

assertEnv('HOSTNAME', 'supers.localhost:1235')
assertEnv('DEMO_PROJECT_NAME', 'demo')
assertEnv('GRIPELESS_PROJECT_NAME', 'bungee')
assertEnv('SDK_URL', 'https://sdk.supers.localhost:1212')
assertEnv('SUPPORT_EMAIL', 'support@supers.localhost')
assertEnv('API_URL', 'https://api.supers.localhost:5550')

assertEnv('FIREBASE_API_KEY', '---')
assertEnv('FIREBASE_AUTH_DOMAIN', '---')
assertEnv('FIREBASE_DATABASE_URL', '---')
assertEnv('FIREBASE_PROJECT_ID', '---')
assertEnv('FIREBASE_STORAGE_BUCKET', '---')
assertEnv('FIREBASE_MESSAGING_SENDER_ID', '---')
assertEnv('FIREBASE_APP_ID', '---')
assertEnv('FIREBASE_MEASUREMENT_ID', '---')

assertEnv('STRIPE_PK', '---')

const httpsCredentials = {
	key: '../../cert/supers.localhost+1-key.pem',
	cert: '../../cert/supers.localhost+1.pem',
}

const bundler = new Bundler(
	fg.sync(
		['source/*.{pug,html}', 'source/blog/*.pug', '!**/_*'].concat(
			isEnvDev ? ['source/dev/*.pug'] : []
		)
	),
	{
		//@ts-ignore
		autoInstall: false,
		logLevel: 4 as any,
		hmrHostname: 'supers.localhost',
		// `https` for hmr's websocket server
		https: httpsCredentials,
		sourceMaps: isEnvDev,
	}
)

const clean = () => del('dist')
const bundle = () => bundler.bundle()

const serve = async () => {
	const app = makeApp()

	const port = 1235
	https
		.createServer(
			{
				key: await fs.readFile(httpsCredentials.key, 'utf8'),
				cert: await fs.readFile(httpsCredentials.cert, 'utf8'),
			},
			app
		)
		.listen(port, () =>
			console.log('[server]', `https://supers.localhost:${port}`)
		)
}

const dev = series(bundle, serve)
const build = series(clean, bundle)

module.exports = {
	build,
	dev,
	serve,
}
