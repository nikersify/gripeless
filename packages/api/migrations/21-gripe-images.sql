alter table gripes
	add column image_id uuid references images(id) on delete set null;
