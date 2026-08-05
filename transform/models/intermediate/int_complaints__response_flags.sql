-- Grain: one row per complaint (inherited from staging).
-- NOTE: unit-test target for Module 5 — ordered case branching, a null
-- case, and a fallback make data tests useless here and unit tests essential.
with complaints as (

    select * from {{ ref('stg_cfpb__complaints') }}

),

classified as (

    select
        complaint_id,
        received_date,
        sent_to_company_date,
        company_response,

        -- did the company respond within the CFPB's expected window?
        (is_timely_response = 'Yes')                          as is_timely,

        -- relief replaces the consumer-dispute rate, retired by CFPB in 2017
        company_response in ('Closed with monetary relief',
                             'Closed with non-monetary relief') as got_relief,

        case
            when company_response is null                        then 'no_response'
            when company_response like 'Closed with monetary%'   then 'monetary_relief'
            when company_response like 'Closed with non-monetary%' then 'nonmonetary_relief'
            when company_response like 'Closed with explanation%' then 'explanation_only'
            when company_response = 'In progress'                then 'in_progress'
            else 'other'
        end                                                    as response_bucket,

        datediff('day', received_date, sent_to_company_date)   as days_to_company

    from complaints

)

select * from classified
