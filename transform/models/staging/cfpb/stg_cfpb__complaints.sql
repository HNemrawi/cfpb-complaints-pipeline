-- Grain: one row per complaint. The project's only reader of the CFPB source.
with source as (

    select * from {{ source('cfpb', 'complaints') }}

),

renamed as (

    select
        -- ids
        "Complaint ID"::varchar                         as complaint_id,

        -- dates
        "Date received"::date                           as received_date,
        "Date sent to company"::date                    as sent_to_company_date,

        -- categorization
        nullif(trim("Product"), '')                     as product,
        nullif(trim("Sub-product"), '')                 as sub_product,
        nullif(trim("Issue"), '')                       as issue,
        nullif(trim("Sub-issue"), '')                   as sub_issue,
        nullif(trim("Tags"), '')                        as tags,

        -- parties & place
        nullif(trim("Company"), '')                     as company_name_raw,
        -- 'NONE' is a source sentinel meaning no state was given; 'UNITED STATES
        -- MINOR OUTLYING ISLANDS' is the full name of the jurisdiction coded UM.
        case upper(nullif(trim("State"), ''))
            when 'NONE'                                 then null
            when 'UNITED STATES MINOR OUTLYING ISLANDS' then 'UM'
            else upper(nullif(trim("State"), ''))
        end                                             as state_code,
        nullif(trim("ZIP code"), '')                    as zip_code,
        nullif(trim("Submitted via"), '')               as submission_channel,

        -- outcome
        nullif(trim("Company response to consumer"), '') as company_response,
        nullif(trim("Company public response"), '')     as company_public_response,
        "Timely response?"                              as is_timely_response,

        -- metadata
        _loaded_at                                      as loaded_at

    from source
    where "Complaint ID" is not null
      and "Date received" >= '{{ var("start_date") }}'

)

select * from renamed
