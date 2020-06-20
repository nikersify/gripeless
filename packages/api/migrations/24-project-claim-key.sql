alter table projects
	add column claim_key text unique check (char_length(claim_key) = 32);
