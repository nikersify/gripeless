import execa from 'execa'

const main = async () => {
	const {stdout: status} = await execa('git', ['status', '--porcelain'])

	if (status !== '') {
		throw new Error('git tree is not clean')
	}
}

if (require.main === module) {
	main()
}

process.on('unhandledRejection', error => {
	throw error
})

export default main
