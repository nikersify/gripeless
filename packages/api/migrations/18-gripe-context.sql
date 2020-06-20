create extension if not exists "hstore";

alter table gripes
	add column context hstore not null default ''::hstore;
