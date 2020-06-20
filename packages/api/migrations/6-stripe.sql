create table stripe_handled_events (
	id text not null
);

alter table users
	add column stripe_customer_id text;
