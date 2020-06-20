const path = require('path')

const commonjs = require('@rollup/plugin-commonjs')
const elm = require('rollup-plugin-elm')
const postcss = require('rollup-plugin-postcss')
const replace = require('@rollup/plugin-replace')
const resolve = require('@rollup/plugin-node-resolve')
const string = require('rollup-plugin-string')
const ts = require('@wessberg/rollup-plugin-ts')
const visualizer = require('rollup-plugin-visualizer')
const {terser} = require('rollup-plugin-terser')

const envDev = (process.env.NODE_ENV || '').toLowerCase() !== 'production'

const assertEnv = (key, defaultValue) => {
	const value = process.env[key]

	if (value === undefined) {
		if (envDev) {
			return defaultValue
		}

		throw new TypeError(`process.env.${key} is not defined`)
	}

	return value
}

const hostname = assertEnv('HOSTNAME', 'supers.localhost:1235')
const apiURL = assertEnv('API_URL', 'https://api.supers.localhost:5550')

module.exports = {
	input: 'source/index.ts',
	onwarn: warning => {
		// Throw all warnings

		if (warning.code === 'THIS_IS_UNDEFINED') {
			return
		}

		throw new Error(warning.message)
	},
	plugins: [
		replace({
			'process.env.HOSTNAME': JSON.stringify(hostname),
			'process.env.API_URL': JSON.stringify(apiURL)
		}),
		ts(),
		commonjs(),
		resolve({extensions: ['.js', '.css', '.elm']}),
		string.string({
			include: '../**/*.css'
		}),
		elm({
			exclude: 'elm-stuff/**',
			compiler: {
				debug: envDev,
				optimize: !envDev,
				cwd: path.resolve('../elm')
			}
		})
	].concat(envDev ? [] : [
		visualizer({brotliSize: true}),
		terser({
			// https://github.com/elm/compiler/blob/master/hints/optimize.md
			compress: {
				keep_fargs: false,
				pure_funcs: ['F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A9'],
				pure_getters: true,
				unsafe: true,
				unsafe_comps: true
			}
		})
	]),
	output: {
		exports: 'named',
		name: 'Gripeless',
		dir: 'dist',
		format: 'umd'
	}
}
