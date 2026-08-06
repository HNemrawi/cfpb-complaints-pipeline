-- Module 2 audit: does the star schema reproduce the monolith it replaced?
--
-- The "before" artifact is analyses/legacy_company_scorecard.sql (Unit 2.1):
-- one query against raw, grouped by the raw company string, with the timely and
-- relief case expressions each written twice.
--
-- Two deliberate differences from that monolith:
--
--  1. DATES ARE PINNED. The monolith filters `current_date - interval 90 day`,
--     so its window slides every day and its output cannot be compared against
--     a baseline recorded on any other date. NOTES.md captured the baseline on
--     2026-08-04, when that window began 2026-05-06. An audit whose window
--     moves is not an audit.
--
--  2. source() instead of a hardcoded "dev"."raw"."cfpb_complaints". The
--     monolith is welded to the dev target; this runs against whatever target
--     it is invoked with. The rulebook confines source() to staging models —
--     this is an analysis, not a model, and comparing the warehouse against raw
--     is the entire point of the file.
--
-- The `::date` cast on "Date received" is load-bearing: the raw column is
-- timestamp-with-timezone, so comparing it to a bare date would include or
-- exclude boundary rows depending on the session timezone. Staging casts to
-- date, so the audit must too, or the two sides disagree by a few hours' worth
-- of complaints and the discrepancy looks like a modelling bug.

{% set window_start = '2026-05-06' %}
{% set audited_products = [
    'Credit reporting or other personal consumer reports',
    'Mortgage',
    'Checking or savings account'
] %}

with legacy as (

    select
        count(distinct c."Company")                     as companies,
        count(*)                                        as complaints,
        sum(case when c."Timely response?" = 'Yes' then 1 else 0 end) as timely_ct,
        sum(
            case
                when c."Company response to consumer" in (
                    'Closed with monetary relief',
                    'Closed with non-monetary relief'
                )
                then 1
                else 0
            end
        )                                               as relief_ct
    from {{ source('cfpb', 'complaints') }} c
    where c."Date received"::date >= date '{{ window_start }}'
      and c."Product" in (
          {%- for p in audited_products %}
          '{{ p }}'{{ "," if not loop.last }}
          {%- endfor %}
      )

),

star as (

    select
        count(distinct f.company_key)                   as companies,
        count(*)                                        as complaints,
        sum(case when f.is_timely  then 1 else 0 end)   as timely_ct,
        sum(case when f.got_relief then 1 else 0 end)   as relief_ct
    from {{ ref('fct_complaints') }} f
    inner join {{ ref('dim_product') }} p
        on f.product_key = p.product_key
    where f.received_date >= date '{{ window_start }}'
      and p.product in (
          {%- for prod in audited_products %}
          '{{ prod }}'{{ "," if not loop.last }}
          {%- endfor %}
      )

),

compared as (

    select 'legacy_monolith' as source, * from legacy
    union all
    select 'star_schema',      * from star

)

select * from compared

-- What must match: complaints, timely_ct, relief_ct. Those are the numbers a
-- stakeholder would notice changing, and the refactor is only trustworthy if
-- they are identical.
--
-- What is EXPECTED to differ: `companies`. The monolith groups by the raw
-- company string; the star groups by a canonical company. Canonicalisation is
-- almost entirely a 1:1 rename (legal entity -> brand), but one genuine merge
-- exists in the data — V.I.P. MORTGAGE, INC. and VIP Mortgage Inc. — so the
-- star should report exactly one fewer company if both spellings fall inside
-- this window and product list. A difference of 1 is the fix working. Any other
-- difference is a bug worth chasing.
