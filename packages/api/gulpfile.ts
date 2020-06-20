import {promises as fs} from 'fs'
import path from 'path'

import {codegen} from '@graphql-codegen/core'
import * as typescriptPlugin from '@graphql-codegen/typescript'
import * as typescriptResolversPlugin from '@graphql-codegen/typescript-resolvers'
import {schemaPath} from '@gripeless/schema'
import {dim, red, yellow} from 'chalk'
import del from 'del'
import execa from 'execa'
import fancyLog from 'fancy-log'
import {buildSchema, parse, printSchema} from 'graphql'
import {TaskFunction, dest, parallel, series, src, watch} from 'gulp'
import * as tsb from 'gulp-tsb'
import httpProxy from 'http-proxy'
import makeDir from 'make-dir'

const cleanDist = () => del('dist')
const cleanGql = () => del('source/generated')

const isEnvDev =
	(process.env.NODE_ENV || '').toLowerCase() !== 'production'

const compilation = tsb.create(
	path.join(__dirname, 'tsconfig.json'),
	{
		skipLibCheck: isEnvDev,
		noEmitOnError: false
	},
	false,
	msg => {
		fancyLog.error(red('Error:'), dim(msg))
		if (!isEnvDev) {
			process.exit(1)
		}
	}
)

const typescript = () =>
	src('source/**/*')
		.pipe(compilation())
		.pipe(dest('dist'))

const gqlCodegen: TaskFunction = async () => {
	const schema = buildSchema(await fs.readFile(schemaPath, 'utf-8'))

	const filename = './source/generated/resolvers.ts'

	const output = await codegen({
		filename,
		config: {
			avoidOptionals: true,
			nonOptionalTypename: true,
			typesPrefix: 'I'
		},
		plugins: [
			{
				typescript: {
					scalars: {
						PosixTime: 'Date',
						GripeID: 'string',
						KeyValueString: '[string, string]'
					}
				}
			},
			{
				typescriptResolvers: {
					optionalResolveType: true,
					contextType: '../types/Context#Context',
					useIndexSignature: true,
					mappers: {
						User: '../types/loader-types#User',
						Gripe: '../types/loader-types#Gripe',
						Project: '../types/loader-types#Project'
					}
				}
			}
		],
		pluginMap: {
			typescript: typescriptPlugin,
			typescriptResolvers: typescriptResolversPlugin
		},
		schema: parse(printSchema(schema)),
		documents: []
	})

	await makeDir(path.dirname(filename))
	await fs.writeFile(filename, output)
}

let currentServer: execa.ExecaChildProcess | undefined
let currentProxy: httpProxy

const server: TaskFunction = async () => {
	const log = (...msg: string[]) => fancyLog(dim('[server]'), ...msg)

	if (currentServer) {
		log('Killing old instance')

		const kill = currentServer.kill.bind(currentServer)
		process.nextTick(kill)

		const _currentServer = currentServer
		await new Promise(resolve => {
			_currentServer.on('exit', resolve)
		})
	}

	if (!currentProxy) {
		const proxyPort = 5550

		log(`Starting HTTPS proxy on port ${proxyPort}`)

		currentProxy = httpProxy
			.createServer({
				target: 'http://localhost:4000',
				ssl: {
					key: await fs.readFile(
						'../../cert/supers.localhost+1-key.pem'
					),
					cert: await fs.readFile(
						'../../cert/supers.localhost+1.pem'
					)
				}
			})
			.on('error', e => console.error(e.message))
			// https://github.com/http-party/node-http-proxy/blob/9bbe486c5efcc356fb4d189ef38eee275bbde345/lib/http-proxy/index.js#L124-L139
			//@ts-ignore
			.listen(proxyPort, '127.0.0.1')

		log('HTTPS proxy listening on https://api.supers.localhost:5550/')
	}

	log('Starting server')

	currentServer = execa
		.node(path.join(__dirname, 'dist/index.js'), {
			stdout: 'inherit',
			stderr: 'inherit'
		})
		.on('exit', (code, signal: string | null) => {
			log(
				`Exited with code ${code}` +
					(signal === null ? '' : ` on ${signal}`)
			)
			currentServer = undefined
		})
}

const dev: TaskFunction = series(cleanDist, async () => {
	// On ts file change, or pkg.json, rebuild ts and restart server
	// On graphql.schema change, rebuild schema, rebuild ts, restart server
	watch(
		['source/**/*', '!source/generated/**', 'package.json'],
		series([typescript, server])
	)

	watch(
		['codegen.yml', schemaPath],
		{ignoreInitial: false},
		series([cleanGql, gqlCodegen, typescript, server])
	)
})

const build: TaskFunction = series(
	async () => {
		if (isEnvDev) {
			fancyLog.warn(
				yellow.bold(
					'Warning: Running build task in development mode'
				)
			)
		}
	},
	parallel(cleanDist, cleanGql),
	series(gqlCodegen, typescript)
)

module.exports = {
	build,
	cleanDist,
	cleanGql,
	dev,
	gqlCodegen,
	server,
	typescript
}
