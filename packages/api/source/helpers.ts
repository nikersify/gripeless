import {
	DatabasePoolType,
	DatabaseTransactionConnectionType,
	sql
} from 'slonik'

// Ensure anonymous user is in the database
export const createUserIfNotExists = (
	db: DatabasePoolType | DatabaseTransactionConnectionType
) => (uid: string) =>
	db.query(sql`
		insert into users (uid)
		values (${uid})
		on conflict do nothing
	`)
