const path = require('path')
const cssnano = require('cssnano')

const production =
	(process.env.NODE_ENV || '' .toLowerCase()) === 'production'

module.exports = {
	plugins: [
		require('postcss-each'),
		require('tailwindcss')(path.join(__dirname, 'tailwind.config.js')),
	].concat(
		production ? require('@fullhuman/postcss-purgecss')({
			content: [
				path.join(__dirname, '../elm/**/*.elm'),
				path.join(__dirname, '../ui/**/*.{ts,pug,html}'),
				path.join(__dirname, 'source.css')
			],
			defaultExtractor: content => content.match(/[A-Za-z0-9-_:/]+/g) || [],
			whitelistPatterns: [/fade-transition-\S+/]
		}) : []
	).concat(
		production ? cssnano() : []
	)
}
