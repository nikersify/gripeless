const defaultConfig = require('tailwindcss/defaultConfig')

const defaultTheme = defaultConfig.theme
const defaultVariants = defaultConfig.variants

module.exports = {
	theme: {
		extend: {
			cursor: {
				crosshair: 'crosshair',
				none: 'none',
				help: 'help'
			},
			inset: {
				'1': '0.25rem',
				'2': '0.5rem',
				'3': '0.75rem',
				'-1': '-0.25rem',
				'-2': '-0.5rem',
				'-3': '-0.75rem'
			},
			minHeight: {
				'24': '6rem'
			},
			opacity: {
				'1': '0.01'
			},
			width: {
				'80': '20rem',
				'96': '24rem',
				'128': '32rem'
			},
			fontFamily: {
				base: [
					'Inter',
					...defaultTheme.fontFamily.sans
				],
				display: [
					'Asap',
					...defaultTheme.fontFamily.sans
				],
				serif: [
					'Caladea',
					...defaultTheme.fontFamily.serif
				]
			}
		}
	},
	variants: {
		backgroundColor: ['disabled', 'group-hover', ...defaultVariants.backgroundColor],
		borderColor: ['disabled', ...defaultVariants.borderColor],
		borderRadius: ['first', 'last', ...defaultVariants.borderRadius],
		borderWidth: ['first', 'last', ...defaultVariants.borderWidth],
		cursor: ['disabled', ...defaultVariants.cursor],
		display: ['group-hover', ...defaultVariants.display],
		margin: ['first', 'last', ...defaultVariants.margin],
		padding: ['last', ...defaultVariants.padding],
		textColor: ['disabled', 'group-hover', ...defaultVariants.textColor],
		visibility: ['group-hover', ...defaultVariants.visibility]
	},
	plugins: []
}
