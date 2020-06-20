create type device_platform as enum ('desktop', 'mobile', 'tablet', 'tv');

alter table gripes
	add column device_user_agent text,
	add column device_viewport_size text,
	add column device_browser text,
	add column device_engine text,
	add column device_os text,
	add column device_platform device_platform;
