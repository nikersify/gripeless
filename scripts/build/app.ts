import execa from 'execa'

const toBuild = ['elm', 'css', 'sdk', 'api', 'ui'].map(
	w => `@gripeless/${w}`
)

if ((process.env.NODE_ENV || '').toLowerCase() !== 'production') {
	throw new Error(
		'This build script must be ran with NODE_ENV === `production`'
	)
}

const log = (...msgs: string[]) => console.log(new Date(), ...msgs)

const main = async () => {
	for (const workspace of toBuild) {
		log('Building', workspace)
		await execa('yarn', ['workspace', workspace, 'build'], {
			stderr: 'inherit',
			stdout: 'inherit'
		})
	}
}

process.on('unhandledRejection', error => {
	throw error
})

main()
