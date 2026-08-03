"""Extract-load: CFPB complaint CSV export -> Parquet -> DuckDB raw.cfpb_complaints.

Idempotent by construction: the raw table is replaced wholesale each run.
Incrementality lives downstream in dbt, not here.
"""
import argparse
import os

import duckdb
import requests

API = "https://www.consumerfinance.gov/data-research/consumer-complaints/search/api/v1/"
DB = os.environ.get("CPULSE_DB", "warehouse/dev.duckdb")
START = os.environ.get("CPULSE_START", "2026-07-01")
RAW_CSV = "data/raw/cfpb_complaints.csv"
RAW_PARQUET = "data/raw/cfpb_complaints.parquet"


def fetch(date_from, path=RAW_CSV):
    """One streamed CSV export request — format=csv ignores size/frm, so no pagination.

    NB: the JSON API caps size at 100 and rejects an explicit format=json (400),
    so the CSV export is the only sane bulk path. See NOTES.md.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with requests.get(API, params={
        "date_received_min": date_from,
        "format": "csv",
        "no_aggs": "true",
    }, timeout=600, stream=True) as r:
        r.raise_for_status()
        with open(path, "wb") as f:
            for chunk in r.iter_content(chunk_size=1 << 20):
                f.write(chunk)
    print(f"fetched {os.path.getsize(path):,} bytes -> {path}")


def load(db=DB, limit=None):
    limit_clause = f"limit {int(limit)}" if limit else ""
    con = duckdb.connect(db)
    con.execute("create schema if not exists raw")
    # Narratives are big and unneeded; everything else lands raw — renaming
    # and casting belong to dbt staging, where they are versioned and tested.
    con.execute(f"""
        copy (
            select * exclude ("Consumer complaint narrative")
            from read_csv_auto('{RAW_CSV}')
            {limit_clause}
        ) to '{RAW_PARQUET}'
    """)
    con.execute(f"""
        create or replace table raw.cfpb_complaints as
        select *, current_timestamp as _loaded_at
        from '{RAW_PARQUET}'
    """)
    n = con.execute("select count(*) from raw.cfpb_complaints").fetchone()[0]
    con.close()
    print(f"loaded {n:,} rows -> {db}:raw.cfpb_complaints")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Load CFPB complaints into DuckDB")
    p.add_argument("--start", default=START, help="date_received_min (YYYY-MM-DD)")
    p.add_argument("--db", default=DB, help="DuckDB file path")
    p.add_argument("--limit", type=int, default=None,
                   help="load at most N rows (fast iteration; fetch is still full)")
    p.add_argument("--skip-fetch", action="store_true",
                   help="reuse the CSV already on disk")
    args = p.parse_args()

    if not args.skip_fetch:
        fetch(args.start)
    load(args.db, args.limit)
