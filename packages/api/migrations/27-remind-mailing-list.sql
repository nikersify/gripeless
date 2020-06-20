create table remind_emails (
	email text unique not null,
	created_at timestamp default now()
);
