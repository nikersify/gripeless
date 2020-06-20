create table blog_emails (
	email text unique not null,
	created_at timestamp default now()
);
