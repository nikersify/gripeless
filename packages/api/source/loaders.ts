import {UserInputError} from 'apollo-server-express'
import DataLoader from 'dataloader'
import * as fp from 'fp-ts'
import {findFirst, map} from 'fp-ts/lib/Array'
import {Either} from 'fp-ts/lib/Either'
import {pipe} from 'fp-ts/lib/pipeable'
import * as t from 'io-ts'
import {DatabasePoolType, sql} from 'slonik'

import * as loaderTypes from './types/loader-types'
import {parseOrThrow} from './util'

// When the user sends invalid input, e.g. 404
type LoaderInputError = {
	kind: 'input'
	error: UserInputError
}

// When something fails server side, we want to know about this shit
type LoaderServerError = {
	kind: 'server'
	error: t.Errors
}

export type LoaderError = LoaderInputError | LoaderServerError

const inputError = (u: UserInputError): LoaderInputError => ({
	kind: 'input',
	error: u
})

const serverError = (u: t.Errors): LoaderServerError => ({
	kind: 'server',
	error: u
})

type Loader<V, K = string> = DataLoader<K, Either<LoaderError, V>>

export type Loaders = {
	user: Loader<loaderTypes.User>
	projectById: Loader<loaderTypes.Project>
	projectByName: Loader<loaderTypes.Project>
	gripe: Loader<loaderTypes.Gripe>
	gripeComment: Loader<loaderTypes.GripeComment>
	gripeStatusEvent: Loader<loaderTypes.GripeStatusEvent, number>
	gripeStatusEventIdsByGripeIds: Loader<loaderTypes.GripeStatusEventIds>
}

const sqlTuple = (items: (string | number)[]) =>
	sql`(${sql.join(items, sql`, `)})`

const assertArrayOfUnknowns = (rows: unknown) =>
	parseOrThrow(t.array(t.record(t.string, t.unknown)))(rows)

const matchRows = <
	Codec extends t.Any,
	IDColumn extends string,
	IDs extends string | number,
	Result extends t.TypeOf<Codec>
>(
	codec: Codec,
	idColumn: IDColumn,
	ids: readonly IDs[],
	rows: unknown[]
): Either<LoaderError, Result>[] => {
	return pipe(
		ids.concat(),

		// Assign a result column to each name, or option.None if none found
		map(name =>
			pipe(
				assertArrayOfUnknowns(rows),
				findFirst(r => r[idColumn] === name)
			)
		),

		// If nothing is found we can basically assume it's a 404 and map the
		// option.None into a UserInputError (might switch that later to
		// NotFound and throw it with an apollo error down the road)
		fp.array.map(
			fp.either.fromOption(() =>
				inputError(new UserInputError(`${codec.name} not found`))
			)
		),

		// Run decoder on the Right values
		fp.array.map(
			fp.either.map(y =>
				pipe(codec.decode(y), fp.either.mapLeft(serverError))
			)
		),

		// Squash `Either<LoaderInputError, Either<LoaderServerError, x>[]`
		// into `Either<LoaderError, x>[]`
		fp.array.map(x => fp.either.flatten<LoaderError, Result>(x))
	)
}

const selectProjectSql = sql`
	select
		id,
		created_at,
		name,
		subscription_valid_until,
		onboarding_step,
		owner_uid
	from projects_view
`

export const makeLoaders: (db: DatabasePoolType) => Loaders = db => ({
	user: new DataLoader(async uids => {
		const rows = await db.any(sql`
			select
				u.uid,
				u.created_at,
				data is null as is_anonymous,
				data.email,
				data.name,
				data.picture,
				data.stripe_customer_id,
				data.created_at as data_created_at
			from users u
			left outer join users_data data on u.uid = data.uid
			where u.uid in ${sqlTuple(uids.concat())}
		`)

		return matchRows(loaderTypes.User, 'uid', uids, rows)
	}),
	projectById: new DataLoader(async ids => {
		const rows = await db.any(sql`
			${selectProjectSql}
			where id in ${sqlTuple(ids.concat())}
		`)

		return matchRows(loaderTypes.Project, 'id', ids, rows)
	}),
	projectByName: new DataLoader(async names => {
		const rows = await db.any(sql`
			${selectProjectSql}
			where name in ${sqlTuple(names.concat())}
		`)

		return matchRows(
			loaderTypes.Project,
			'name',

			names,
			rows
		)
	}),
	gripe: new DataLoader(async ids => {
		const rows = await db.any(sql`
			with results as (
				select
					gripes as g,
					gripe_event_fsm(events.event order by events.id) as status
				from
					gripes
				left outer join gripe_events events
					on events.gripe_id = gripes.id
				where gripes.id in ${sqlTuple(ids.concat())}
				group by gripes
			) select
				(g).id,
				(status).title,
				(status).status,
				(g).project_id,
				(g).body,
				(g).image_id,
				(g).context,
				(g).notify_email,
				(g).device_url,
				(g).device_user_agent,
				(g).device_viewport_size,
				(g).device_browser,
				(g).device_engine,
				(g).device_os,
				(g).device_platform,
				(g).created_at,
				greatest(events.created, comments.created_at) as updated_at
			from results
				left outer join gripe_events events
					on events.gripe_id = (g).id
				left outer join gripe_comments comments
					on comments.gripe_id = (g).id;
		`)

		return matchRows(loaderTypes.Gripe, 'id', ids, rows)
	}),
	gripeStatusEventIdsByGripeIds: new DataLoader(async gripeIds => {
		const rows = await db.any(sql`
			select
				g.id as gripe_id,
				array_remove(array_agg(e.id), NULL) as ids
			from gripes g
			left join gripe_events e on e.gripe_id = g.id
			where g.id in ${sqlTuple(gripeIds.concat())}
			group by g.id
		`)

		return matchRows(
			loaderTypes.GripeStatusEventIds,
			'gripe_id',
			gripeIds,
			rows
		)
	}),
	gripeComment: new DataLoader(async ids => {
		const rows = await db.any(sql`
			select
				id,
				author_uid,
				body,
				created_at
			from gripe_comments
			where id in ${sqlTuple(ids.concat())}
		`)

		return matchRows(loaderTypes.GripeComment, 'id', ids, rows)
	}),
	gripeStatusEvent: new DataLoader(async ids => {
		const rows = await db.any(sql`
			select
				id,
				(event).event,
				(event).data,
				created as created_at
			from gripe_events
			where id in ${sqlTuple(ids.concat())}
		`)

		return matchRows(loaderTypes.GripeStatusEvent, 'id', ids, rows)
	})
})
