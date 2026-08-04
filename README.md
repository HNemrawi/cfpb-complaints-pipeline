# Consumer Complaint Pulse

An end-to-end analytics pipeline over the [CFPB Consumer Complaint Database](https://www.consumerfinance.gov/data-research/consumer-complaints/):

**Python** (extract/load) → **DuckDB** (warehouse) → **dbt Core 1.11** (transform, test, document) → **Evidence** (BI-as-code) — automated with **GitHub Actions**.

> 🚧 Work in progress. Built module-by-module as a dbt Analytics Engineering certification study project. Architecture diagram and design decisions land here as the project grows.

## Status

| Module | Theme | Status |
|---|---|---|
| 1 | Foundations — ingest, sources, staging | ✅ done |
| 2 | Modeling — dimensional marts | 🔨 in progress |
| 3 | Jinja, macros & packages | not started |
| 4 | Incremental & snapshots | not started |
| 5 | Testing | not started |
| 6 | Governance & documentation | not started |
| 7 | Production — CI/CD, dashboard | not started |
