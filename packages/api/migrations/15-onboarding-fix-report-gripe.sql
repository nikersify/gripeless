create or replace view projects_view as
	with results as (
		select
			projects,
			(case projects.onboarding_done
				when true then 'done'::onboarding_step_enum
				else case count(gripes)
					when 1 then 'report-gripe'::onboarding_step_enum
					else case cardinality(
						array_remove(array_agg(gripes.title), null)
					)
						when 0 then 'title-gripe'::onboarding_step_enum
						else case cardinality(
							array_remove(
								array_agg(gripes.status),
								'open'::gripe_status_enum
							)
						)
							when 0 then 'take-action-on-gripe'::onboarding_step_enum
							else case (every(users.data is null))
								when true then 'sign-in'
								else case (array_agg(gripes.status))[1]
									when 'completed' then 'have-fun'::onboarding_step_enum
									else 'install'::onboarding_step_enum
								end
							end
						end
					end
				end
			end)::onboarding_step_enum as onboarding_step
		from projects
		left join (select * from gripes_view order by created_at asc) gripes on gripes.project_id = projects.id
		left join users_view users on users.uid = projects.owner_uid
		group by projects, projects.onboarding_done
	) select (projects).*, onboarding_step from results;
