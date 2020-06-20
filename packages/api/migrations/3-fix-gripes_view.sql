drop view gripes_view;

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
