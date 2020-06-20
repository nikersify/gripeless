alter table projects
drop constraint realms_owner_uid_fkey;

alter table projects
	add constraint projects_owner_uid_fkey foreign key (owner_uid) references users(uid) match full;
