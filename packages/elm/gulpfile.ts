import {Stats, promises as fs} from 'fs'
import path from 'path'

import {schemaPath} from '@gripeless/schema'
import execa from 'execa'
import {TaskFunction, series, watch} from 'gulp'
import npmRunPath from 'npm-run-path'
import tempy from 'tempy'

// 1. compile the Api stuffs
// 2. move the old directory to tmp
// 3. (optional) rm -rf old directory
// 4. move new directory to Api
// 5. touch some file (probably Query.elm) in api to trigger compilation

const elmSourcePath = path.join(__dirname, 'source')

const pathExists = (p: string): Promise<Stats | false> =>
	fs.stat(p).catch(error => {
		if (error.code === 'ENOENT') {
			return false
		}
		throw error
	})

const dirExists = (p: string): Promise<boolean> =>
	pathExists(p).then(stat => {
		return stat ? stat.isDirectory() : false
	})

const makeLog = (label: string) => (...msgs: any) =>
	console.log(`[${label}]`, ...msgs)

const generateApi = (withScalars: boolean) => async () => {
	const log = makeLog('api')
	const outputPath = tempy.directory()

	log('Generating...')
	await execa(
		'elm-graphql',
		['--schema-file', schemaPath, '--output', outputPath].concat(
			withScalars ? ['--scalar-codecs', 'ScalarCodecs'] : []
		),
		{
			env: npmRunPath.env(),
			cwd: elmSourcePath,
			stderr: 'inherit'
		}
	)

	const destination = path.join(elmSourcePath, 'Api')

	if (await dirExists(destination)) {
		// Doing an fs.rename rather than rm -rf because it won't trigger
		// parcel's watcher
		log(`Moving old Api out`)
		await fs.rename(destination, tempy.directory())
	}

	log(`Writing to ${destination}`)
	await fs.rename(path.join(outputPath, 'Api'), destination)

	// Touch some file inside to trigger parcel's recompilation
	const touchTarget = path.join(destination, 'Query.elm')
	log(`Touching ${touchTarget}`)
	const t = new Date()
	await fs.utimes(touchTarget, t, t)
}

// Can't easily curry because it breaks the gulp names
const api: TaskFunction = async () => generateApi(true)()
const apiWithoutScalars: TaskFunction = async () => generateApi(false)()

const interop: TaskFunction = async () =>
	execa('elm-typescript-interop', {
		cwd: __dirname,
		env: npmRunPath.env(),
		stdout: 'inherit',
		stderr: 'inherit'
	})

const watch_: TaskFunction = () => {
	watch(
		[
			path.join(elmSourcePath, '**/*.elm'),
			path.join('!', elmSourcePath, 'Api/**/*'),
			path.join('!', elmSourcePath, 'elm-stuff')
		],
		interop
	)

	watch(schemaPath, api)
}

const build: TaskFunction = series(apiWithoutScalars, api, interop)

const dev: TaskFunction = series(build, watch_)

export {api, apiWithoutScalars, interop, dev, build}
