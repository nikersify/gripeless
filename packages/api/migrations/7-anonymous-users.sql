alter table users
	alter column email drop not null,
	alter column name drop not null,
	alter column picture drop not null;
