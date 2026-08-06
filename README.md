# Consumer Complaint Pulse

An end-to-end analytics pipeline over the [CFPB Consumer Complaint Database](https://www.consumerfinance.gov/data-research/consumer-complaints/):

**Python** (extract/load) → **DuckDB** (warehouse) → **dbt Core 1.11** (transform, test, document) → **Evidence** (BI-as-code) — automated with **GitHub Actions**.

> 🚧 Work in progress. Built module-by-module as a dbt Analytics Engineering certification study project. Architecture diagram and design decisions land here as the project grows.

## Status

| Module | Theme | Status |
|---|---|---|
| 1 | Foundations — ingest, sources, staging | ✅ done |
| 2 | Modeling — dimensional marts | ✅ done |
| 3 | Jinja, macros & packages | not started |
| 4 | Incremental & snapshots | not started |
| 5 | Testing | not started |
| 6 | Governance & documentation | not started |
| 7 | Production — CI/CD, dashboard | not started |

## The star schema

Complaints land in one fact table surrounded by four conformed dimensions, with three
aggregates built one-per-dashboard-page. `dbt build` is green at **92 nodes, 0 warnings** —
12 models, 3 seeds, 79 data tests, 1 exposure. The whole warehouse is 13 objects: these 12
plus the raw source table.

| Model | Grain | Rows |
|---|---|---|
| `fct_complaints` | one row per complaint | 1,915,568 |
| `dim_company` | one row per canonical company | 2,554 |
| `dim_date` | one row per calendar day | 2,409 |
| `dim_product` | one row per product / sub-product | 55 |
| `dim_state` | one row per jurisdiction | 63 |
| `agg_complaint_trends_monthly` | month × product group | 560 |
| `agg_company_scorecard` | company, trailing 365 days | 2,554 |
| `agg_state_summary` | jurisdiction × product group | 441 |

`fct_complaints` matches `stg_cfpb__complaints` row for row — the check that proves no
dimension join fanned out and no inner join dropped rows.

### Refactor audit

`analyses/audit_star_vs_legacy.sql` compares the star schema against the monolithic query
it replaced (`analyses/legacy_company_scorecard.sql`), over a **pinned** window because the
monolith's `current_date - 90 day` filter slides:

| source | companies | complaints | timely_ct | relief_ct |
|---|---|---|---|---|
| legacy_monolith | 1418 | 1707729 | 1706399 | 306537 |
| star_schema | 1417 | 1707729 | 1706399 | 306537 |

Every stakeholder-visible number is identical. `companies` differs by exactly one, which is
the single genuine name merge in the data (`V.I.P. MORTGAGE, INC.` / `VIP Mortgage Inc.`)
being collapsed by `seed_company_name_overrides` — the fix working, not a regression.

## dbt_project_evaluator findings

`dbt_project_evaluator` is a **linter, and it is off by default**. Unlike `dbt_utils`, which
ships only macros and materialises nothing, the evaluator ships ~48 models — and on DuckDB the
package materialises them as tables. Left enabled, every `dbt build` drops 48 objects into the
same schema as the real project, sharing `stg_`/`int_`/`fct_` prefixes. So it runs on demand:

```
dbt build --select package:dbt_project_evaluator dbt_project_evaluator_exceptions \
          --vars '{run_project_evaluator: true}'
```

That is clean at **78 nodes, 0 warnings**, and its output lands in
`main_dbt_project_evaluator`, never in `main`. Module 7 wires the same command into CI, which
is where a linter belongs.

Ten findings were raised originally: four were real gaps and were fixed, one was resolved by
configuring the rule, four are justified exceptions recorded in
`seeds/dbt_project_evaluator_exceptions.csv` with reasons, and the two coverage warnings
cleared once the gaps closed.

**Resolved by configuration, not suppression**

- `fct_model_naming_conventions` flagged all three `agg_` models because the package defaults `marts_prefixes` to `['fct_', 'dim_']`. This project's rulebook has always named `agg_` as a mart prefix, so `dbt_project.yml` sets `marts_prefixes: ['fct_', 'dim_', 'agg_']`. Teaching the linter the actual standard beats waiving the finding.

**Fixed**

- `int_dates__spine` was undocumented → described in `_int__models.yml`; documentation coverage 91.7% → 100%.
- `int_complaints__response_flags` and `int_dates__spine` had no primary-key tests → `unique` + `not_null` added on `complaint_id` and `date_day`; test coverage 83.3% → 100%. The first one matters beyond the linter: `fct_complaints` inner-joins on `complaint_id`, so a duplicate there would fan out the entire fact table.
- The exposure depended on three `protected` models → the three aggregates are now `access: public`, which is what they are.

**Justified exceptions**

| Finding | Why it stands |
|---|---|
| `fct_model_fanout` (`fct_complaints` → 3) | By design — one aggregate per dashboard page. The rule targets a mart feeding fifteen near-identical exports. |
| `fct_rejoining_of_upstream_concepts` | `is_loop_independent = True`: the fact takes base attributes from staging and only derived classification columns from the intermediate model. Removing the finding would mean pushing six pass-through columns through that model, turning it into the wide pass-through model the layer rules call the opposite smell. |
| `fct_root_models` (`int_dates__spine`) | Legitimately parentless — a `dbt_utils.date_spine` call that generates rows from `var('start_date')` rather than reading a table. |
| `fct_public_models_without_contract` | **Time-boxed.** Contracts and versions are Module 6's subject. If this row still exists at the end of Module 6, it is a real gap, not an exception. |

## Known data characteristics

- `state_code` is **nullable by design**: 1,732 complaints carry no state. The raw feed encodes this as the literal string `NONE`, which staging normalises to `NULL`; it also carries `UNITED STATES MINOR OUTLYING ISLANDS` as a full name, normalised to its real code `UM`. Consequence: `agg_state_summary` excludes those 1,732 rows, so per-state totals do not reconcile to a project-wide total.
- `seed_state_population` covers 52 of 63 jurisdictions with US Census Vintage 2025 estimates. The other 11 carry `NULL` population — Census gates the 2020 Island Areas Censuses behind an API key, does not publish the freely associated states, and there is no resident population for `UM` or the `AA`/`AE`/`AP` military codes. `dim_state.is_unpopulated` keeps those rows out of per-capita maths.
- Company names are canonicalised for **display**, not deduplication: CFPB already canonicalises at complaint-routing time, so across 2,555 distinct companies there is exactly one punctuation variant pair.
