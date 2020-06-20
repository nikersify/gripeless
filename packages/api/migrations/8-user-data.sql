alter table users rename to users_data;

create table users (
	uid varchar(128) unique not null primary key,
	created_at timestamp default now()
);

insert into users (uid) (select uid from users_data);

alter table users_data
	add constraint users_data_uid_fk foreign key (uid) references users(uid) match full;

create view users_view as
	select
		(u).*,
		data
	from users u
	left outer join users_data data on u.uid = data.uid;

alter table users_data
	alter column name set not null,
	alter column picture set not null,
	alter column email set not null;
