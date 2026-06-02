# Tiders Stack

A complete, working example of the whole infrastructure and steps required to handle blockchain data.

This repo takes one real dataset (Polymarket prediction-market trades on Polygon) and follows it the whole way: 
    - pull raw data from the chain,
    - clean it up, and shaped into tidy tables,
    - shown it in an interactive dashboard,
    - and finally served behind a pay-per-query API.
    
You can run the whole thing on your laptop with 2 commands, learn each step, and then swap in your own data later. You will see that although each step is very flexible and can grow to very complex, there were abstract into a few simple files easier to understand.

If you just want to *use* one of the pieces, each has its own home:

- **[tiders](https://github.com/yulesa/tiders)** — gets data out of blockchains and into a database.
- **[tiders-x402-server](https://github.com/yulesa/tiders-x402-server)** — serves and sells that data over HTTP.

This repo is the glue that shows them working together, end-to-end.

---

## The five pieces

A data product needs more than an indexer. You need somewhere to put the data, a way to clean it, a way to show it, and a way to hand it over. The stack is five components, each doing one job:

| # | Component | Role | What this example uses |
|---|-----------|------|------------------------|
| 1 | **Database** | Stores the data | [ClickHouse](https://clickhouse.com/) |
| 2 | **Ingestion** | Pulls raw data from the chain into the database | [Tiders](https://github.com/yulesa/tiders) |
| 3 | **Transformation** | Cleans and reshapes raw data into useful tables | [dbt](https://www.getdbt.com/) on ClickHouse |
| 4 | **Dashboard** | A static site that visualizes the data | [Evidence](https://evidence.dev/) |
| 5 | **Server** | Serves the dashboard and sells the data | [tiders-x402-server](https://github.com/yulesa/tiders-x402-server) |

None of these choices above are locked in. 
    - Tiders can write to DuckDB, Postgres or Apache Iceberg instead of ClickHouse; 
    - The transformation layer could be Polars, Pandas, or DataFusion instead of dbt;
    - The server speaks to any of its supported databases.
    
We've choose the to combine the tiders tools with ClickHouse + dbt just as a sensible, production-ready default.
In the same way, we choosen Polymarket data for it's importance and simplicity. You can use the same stack for any protocol or onchain data necessity.


```
                                  ┌─────────────────────────────┐
  blockchain ──▶ (2) Tiders ──▶   │        (1) ClickHouse       │
  + public APIs    ingestion      │   raw → staging → mart      │
                                  └──────────────┬──────────────┘
                                       ▲         │
                              (3) dbt  │         │ reads
                              transform ┘        ▼
                                  ┌─────────────────────────────┐
  buyer's browser ──────────────▶│      (5) tiders-x402-server  │
  buyer's wallet  ◀── 402 ───────│   serves (4) Evidence site   │
                  ── pays ──────▶│   sells data via x402 API    │
                                  └─────────────────────────────┘
```

---

## Follow the data: the Polymarket example

The best way to understand the stack is to follow the pipeline through it. Here's the trip a Polymarket dataset, from the chain to a dashboard and paid API endpoint.

### 1. Ingestion — getting the data out of the chain

Polymarket runs on Polygon. Every trade is an `OrderFilled` event emitted by its CTFExchange contracts. **[Tiders](https://github.com/yulesa/tiders)** fetches the contract logs, decodes them, and writes them to ClickHouse.

Two scripts live in [ingestion/polymarket/](ingestion/polymarket/):

- **[polymarket_exchange.py](ingestion/polymarket/polymarket_exchange.py)** — a Tiders pipeline. It points a *provider* (HyperSync, SQD, or a plain RPC node) at the exchange contracts, decodes every event type in the ABI, joins in block timestamps, and writes one raw table per event into ClickHouse (e.g. `raw__polymarket__exchange__event__order_filled`). By default it backfills the last few hours from the chain head, so a fresh run produces data immediately.
- **[polymarket_gamma_markets.py](ingestion/polymarket/polymarket_gamma_markets.py)** — a plain Python scraper. On-chain trades only know a numeric `tokenId`; the human-readable market ("Will X happen?", its outcomes, slug, open/closed flags) lives off-chain in Polymarket's Gamma API. This script looks at which token ids have shown up in trades, fetches just the missing markets, and writes them to `raw__polymarket__gamma__markets`.

Together they give you the two halves you need: *what happened on-chain* and *what those trades mean*.

> The interesting Tiders ideas — swappable providers, Rust-powered decoding, the provider/query/steps/writer pipeline shape — are covered in the [Tiders README](https://github.com/yulesa/tiders). Here it's just one component.

### 2. Transformation — turning raw events into tidy tables

Raw event tables are faithful to the chain but awkward to query: hex-encoded ids, amounts in base units, no market names. The [dbt project](dbt/) reshapes them in layers:

- **`stg__…`** ([staging](dbt/models/stg/)) — thin views over each raw table. Light typing and renaming, no business logic. One per event, plus one for the Gamma markets.
- **`mart__…`** ([mart](dbt/models/mart/)) — the tables people actually want. `mart__polymarket_v2__trades` joins decoded fills against market metadata so each row carries the question text, outcome name, price, fees, and a link back to Polymarket. Alongside it are price rollups (hourly/daily OHLC + VWAP) and reference tables (market details, token→market mapping).

The mart tables are the product. They're what the dashboard charts and what buyers download.

### 3. Dashboard — showing buyers what they'd get

Selling data is hard if nobody can see what's inside. The [Evidence](https://evidence.dev/) project in [dashboards/polymarket_v2/](dashboards/polymarket_v2/) is a static site built from SQL-in-Markdown: KPIs, volume-over-time charts, top markets, top traders, a per-market explorer, and a dataset preview page.

Two things make it more than a normal Evidence site:

- It reads from the same ClickHouse mart tables, so the visuals always match what's for sale.
- It ships with a **Tiders download button**. Click it and the page asks the server for the full table; the server replies "that'll cost X", your wallet signs, and the CSV downloads. The preview is free; the full dataset is paid — handled inline.

The dashboard scaffold (the wallet-connect components, the download button, the source connection) is generated by the server's CLI; you mostly edit [pages/index.md](dashboards/polymarket_v2/pages/index.md) and friends.

### 4. Server — serving the site and selling the data

[tiders-x402-server](https://github.com/yulesa/tiders-x402-server) is the front door. It does two jobs from one process:

- **Serves the dashboard** as a static site at a public URL.
- **Sells the mart tables** over an HTTP API. A buyer sends a SQL query; the server validates it against a safe subset (single-table `SELECT` only — no JOINs, subqueries, or aggregates that could run up your bill), prices it, and replies `402 Payment Required`. The buyer's wallet signs a tiny stablecoin payment via the [x402 protocol](https://x402.org), resends, and gets the results back as a fast Apache Arrow stream.

Which tables are sold, and at what price, is set in [tiders-x402-server/tiders-x402-server.yaml](tiders-x402-server/tiders-x402-server.yaml) — this example charges per row on the six `mart__polymarket_v2__*` tables and points payments at the wallet in your `.env`.

That's the full loop: a trade on Polygon becomes a row anyone on the internet can preview for free and buy for a fraction of a cent.

---

## Quick start

You need [Docker](https://docs.docker.com/get-docker/) with Compose. Nothing else — every tool (Tiders, dbt, the server, Node for the dashboard) runs in a container.

```bash
# 1. Configure
#    This repo ships a working .env for the demo. Edit it to use your own
#    wallet / provider — see Configuration below.

# 2. Bring up the stack
docker compose up --build -d
docker compose logs -f     # watch ClickHouse become healthy

# 3. Run the pipeline: ingest → transform → build dashboard
make polymarket_v2
```

When it finishes:

- **ClickHouse** is at `http://localhost:8123` (the web UI and HTTP API).
- **The server + dashboard** are at `http://localhost:4021`.

To start over from an empty database, `docker compose down -v` wipes the named volumes.

---

## Running the pipeline

The [Makefile](Makefile) orchestrates the per-project pipeline. Each project (here, just `polymarket_v2`) defines its stages in [projects/](projects/).

```bash
make polymarket_v2            # full pipeline: ingest → dbt → dashboard
make polymarket_v2-ingest     # just pull fresh data
make polymarket_v2-dbt        # just rebuild the dbt models
make polymarket_v2-dashboard  # just rebuild the Evidence site
```

Stage targets run across all projects at once: `make ingest`, `make dbt`, `make dashboard`, or `make all`.

Two optional variables pass through to the underlying tools:

```bash
make polymarket_v2-ingest TO_BLOCK=22000000   # stop ingesting at a block
make polymarket_v2 TARGET=prod                # write to the prod database, not dev
```

Under the hood each target is just a `docker compose exec` into the right container — the ingestion container for the Python scripts, the `dbt` container for the models, and a Node container for the dashboard build. The containers stay running idle, so re-running a stage is fast and needs no rebuild.

---

## Configuration

All configuration lives in [.env](.env) (git-ignored). The key values:

| Variable | What it does |
|----------|--------------|
| `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` | ClickHouse credentials, shared by every service |
| `CLICKHOUSE_DB` | The **prod** database name |
| `CLICKHOUSE_DEV_DB` | The **dev** database — where dbt writes by default, so you never touch prod by accident |
| `EVIDENCE_SOURCE__clickhouse__password` | How Evidence reads the DB password (it refuses to store passwords in connection files) |
| `INGESTION_PROVIDER` | `rpc`, `sqd`, or `hypersync` — swap your data source with one value |
| `BEARER_TOKEN` | Auth token for HyperSync / SQD, if your provider needs one |
| `PAY_TO_ADDRESS` | The wallet that receives x402 payments |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token, for exposing the server publicly (optional) |

**Dev vs. prod.** dbt and the ingestion scripts default to `dev`, writing to `CLICKHOUSE_DEV_DB`. The server and dashboard read from the prod database (`CLICKHOUSE_DB`). When your data looks right in dev, re-run with `TARGET=prod` to publish it.

---

## Going public

The Quick Start runs everything locally. To put the dashboard and paid API on the internet without opening ports on your router, the stack includes a commented-out [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) service in [docker-compose.yaml](docker-compose.yaml):

1. Create a tunnel in the Cloudflare Zero Trust dashboard and point a public hostname at `http://tiders-server:4021`.
2. Put the tunnel token in `.env` as `TUNNEL_TOKEN`.
3. Uncomment the `cloudflared` service and `docker compose up -d`.

For a real deployment you'd also remove the `clickhouse` port mapping (so the database isn't reachable from outside the Docker network) and set `server.base_url` in the server config to your public hostname.

---

## Repository layout

```
.
├── docker-compose.yaml      # the whole stack: ClickHouse, ingestion, dbt, server, dashboard builder
├── Makefile                 # orchestrates pipelines; includes projects/*.mk
├── .env                     # all configuration and secrets (git-ignored)
│
├── clickhouse/              # (1) ClickHouse server-setting overrides
├── ingestion/               # (2) Tiders pipelines + Python scrapers
│   └── polymarket/
├── dbt/                     # (3) transformation layer
│   └── models/{stg,mart,helpers}/
├── dashboards/              # (4) Evidence static sites
│   └── polymarket_v2/
├── tiders-x402-server/      # (5) server config + Dockerfile
└── projects/                # per-project Makefiles (one stage chain each)
    └── polymarket_v2.mk
```

---

## Adding your own dataset

The `polymarket_v2` project is a template. To index something else:

1. **Ingest** — add a script (Tiders pipeline or plain Python) under `ingestion/` that writes raw tables to ClickHouse.
2. **Transform** — add `stg__` and `mart__` models under `dbt/models/` for your new tables.
3. **Sell** — list the mart tables and their prices in the server's YAML config.
4. **Show** — scaffold a dashboard (`tiders-x402-server dashboard <slug>`), then edit its pages.
5. **Wire it up** — add a `projects/<name>.mk` with `<name>-ingest`, `<name>-dbt`, and `<name>-dashboard` targets, and add `<name>` to `PROJECTS` in the [Makefile](Makefile).

Everything else — the database, the containers, the payment plumbing — you already have.
