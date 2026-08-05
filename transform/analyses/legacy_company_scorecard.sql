-- legacy company scorecard: the "before" artifact for the Module 2 refactor

select
    c."Company" as company,
    count(*) as complaints,

    sum(
        case
            when c."Timely response?" = 'Yes'
            then 1
            else 0
        end
    ) as timely_ct,

    sum(
        case
            when c."Company response to consumer" in (
                'Closed with monetary relief',
                'Closed with non-monetary relief'
            )
            then 1
            else 0
        end
    ) as relief_ct,

    round(
        100.0 * sum(
            case
                when c."Timely response?" = 'Yes'
                then 1
                else 0
            end
        ) / count(*),
        1
    ) as timely_pct,

    round(
        100.0 * sum(
            case
                when c."Company response to consumer" in (
                    'Closed with monetary relief',
                    'Closed with non-monetary relief'
                )
                then 1
                else 0
            end
        ) / count(*),
        1
    ) as relief_pct

from "dev"."raw"."cfpb_complaints" c

where c."Date received" >= current_date - interval 90 day
  and c."Product" in (
      'Credit reporting or other personal consumer reports',
      'Mortgage',
      'Checking or savings account'
  )

group by 1

order by complaints desc