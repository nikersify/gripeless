create table users (
	uid varchar(128) unique not null primary key,
	name varchar(128) not null,
	picture varchar(128) not null,
	email varchar(128) not null,
	created_at timestamp default now()
);

create table realms (
	id uuid unique not null,
	owner_uid varchar(128) references users(uid) on delete set null,
	name varchar(32) unique not null,
	created_at timestamp default now()
);

create table gripes (
	id uuid unique not null,
	realm_id uuid not null references realms(id) on delete cascade,
	body text not null,
	created_at timestamp default now()
);

create type gripe_status_enum as enum ('open', 'completed', 'discarded', 'error');

create type gripe_status_title_unsafe as (
	status gripe_status_enum,
	title varchar(64)
);

create domain gripe_status_title as gripe_status_title_unsafe check (
	value is distinct from null and (
		(
			(value).status in ('open', 'discarded', 'error')
			and (value).title is null
		) or (
			(value).status is not null
			and (value).title is not null
			and char_length((value).title) > 0
		)
	)
);

create type gripe_status_event_enum as enum('discard', 'restore', 'update-title', 'complete');

create type gripe_status_event_unsafe as (
	event gripe_status_event_enum,
	data varchar(64)
);

create domain gripe_status_event as gripe_status_event_unsafe check (
	(
		(value).event = 'update-title'
		and (value).data is not null
		and char_length((value).data) > 0
	) or (
		(value).event <> 'update-title'
		and (value).data is null
	)
);

create table gripe_events (
	id serial primary key,
	gripe_id uuid not null references gripes(id) on delete cascade,
	event gripe_status_event not null,
	created timestamp default now()
);

create function transition_error_msg(
	from_ text,
	to_ text
) returns varchar(64)
language sql as
$$
	select format('invalid transition from state `%s` to state `%s`', from_,
		to_)
$$;

-- Create gripe_status_title
create function create_gst(
	status gripe_status_enum,
	title varchar(64)
) returns gripe_status_title
language sql as
$$
	select row(status, title)::gripe_status_title
$$;

create function gripe_event_transition(
	state gripe_status_title,
	event gripe_status_event
) returns gripe_status_title
language sql strict as
$$
	select case
		when (state).status = 'discarded' then
			case (event).event
				when 'restore' then create_gst('open', (state).title)
				else create_gst('error', transition_error_msg('discarded', (event).event::text))
			end
		when (state).status = 'open' then
			case (event).event
				when 'discard' then create_gst('discarded', (state).title)
				when 'update-title' then create_gst('open', (event).data)
				when 'complete' then create_gst('completed', (state).title)
				else create_gst('error', transition_error_msg('open', (event).event::text))
			end
		when (state).status = 'completed' then
			create_gst('error', transition_error_msg('open', (event).event::text))
		when (state).status = 'error' then
			create_gst('error', transition_error_msg('error', 'error'))
		else create_gst('error', 'invalid status')
	end;
$$;

create aggregate gripe_event_fsm(gripe_status_event) (
	sfunc = gripe_event_transition,
	stype = gripe_status_title,
	initcond = '(open,)'
);

create function gripe_events_trigger_func() returns trigger
language plpgsql as
$$
	declare
		next_state gripe_status_title = create_gst('error', null);
	begin
		next_state = (
			select gripe_event_fsm(event order by id)
			from (
				select event, id from gripe_events where gripe_id = new.gripe_id
				union
				select new.event, new.id
			) s
		);

		if (next_state).status = 'error' then
			raise exception 'invalid gripe event - %', (next_state).title;
		end if;

		return new;
	end
$$;

create trigger gripe_events_trigger before insert on gripe_events
for each row execute procedure gripe_events_trigger_func();

create view gripes_view as
	with results as (
		select
			g,
			gripe_event_fsm(e.event order by e.id) as status
		from
			gripes g
		left outer join gripe_events e on e.gripe_id = g.id
		group by
			g
	) select
		(g).*,
		(status).*
	from results;
