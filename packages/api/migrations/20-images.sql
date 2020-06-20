create table images (
	id uuid primary key default uuid_generate_v4(),
	data bytea not null,
	ext text not null,
	created_at timestamp not null default now()
);
