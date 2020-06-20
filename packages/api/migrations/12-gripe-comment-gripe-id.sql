drop table gripe_comments;

create table gripe_comments (
	id uuid default uuid_generate_v4(),
	gripe_id uuid references gripes(id) on delete cascade,
	author_id varchar(128) references users(uid) on delete set null,
	body text not null,
	created_at timestamp default now()
);
