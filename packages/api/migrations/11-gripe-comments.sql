create table gripe_comments (
	id uuid default uuid_generate_v4(),
	author_id varchar(128) references users(uid) on delete set null,
	body text not null,
	created_at timestamp default now()
);
