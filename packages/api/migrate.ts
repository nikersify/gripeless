import * as migrations from 'postgres-migrations'

import {getEnv} from './source/env'

const env = getEnv()

export const migrate = async () => {
	const config = {
		database: env.PGDATABASE,
		user: env.PGUSER,
		password: env.PGPASSWORD,
		host: env.PGHOST,
		port: 5432
	}

	await migrations.migrate(config, 'migrations', {
		logger: console.log
	})
}

if (require.main === module) {
	migrate()
}
