<img src="/resources/tiders_logo2.png" alt="Tiders" width="1000">

# Tiders Stack

[![tiders](https://img.shields.io/badge/github-black?style=for-the-badge&logo=github)](https://github.com/yulesa/tiders)
[![tiders-x402-server](https://img.shields.io/badge/github-black?style=for-the-badge&logo=github)](https://github.com/yulesa/tiders-rpc-client)
[![telegram](https://img.shields.io/badge/telegram-blue?style=for-the-badge&logo=telegram)](https://github.com/yulesa/tiders-x402-server)


A complete, working example of the whole infrastructure and the stages required to handle blockchain data.

This repo takes one real dataset (Polymarket prediction-market trades on Polygon) and follows it the whole way:

- pulled raw data from the chain,
- cleaned up and shaped into tidy tables,
- shown in an interactive dashboard,
- and finally served behind a pay-per-query API.

You can run the whole thing on your laptop with two commands, learn each step, and then swap in your own data later. You'll see that although each step is flexible and can grow arbitrarily complex, here it's abstracted into a few simple files that are easy to understand.

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

None of the choices above are locked in:

- Tiders can write to DuckDB, Postgres, or Apache Iceberg instead of ClickHouse;
- the transformation layer could be Polars, Pandas, or DataFusion instead of dbt;
- the server speaks to any of its supported databases.

We combine the Tiders tools with ClickHouse + dbt simply as a sensible, production-ready default. In the same way, we chose Polymarket data for its relevance and simplicity — the same stack works for any protocol or on-chain data need.


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

## Quick start

You need [Docker](https://docs.docker.com/get-docker/) with Compose. Nothing else — every tool (Tiders, dbt, the server, Node for the dashboard) runs in a container and is already configured.

```bash
# 1. Add secrets
# This repo ships a working .env.example for the demo. Copy and rename it to use your own
cp .env.example .env
# Edit the secrets at will, but the current ones already work.

# 2. Bring up the stack
docker compose up --build -d
# In another terminal you can watch the stack and see ClickHouse become healthy
docker compose logs -f

# 3. Run the pipeline: ingest → transform → build dashboard, in prod database
make polymarket_v2 TARGET=prod
```

When it finishes:

- **ClickHouse** is at `http://localhost:8123/play` (the web UI and HTTP API).
- **The server + dashboard** are at `http://localhost:4021`.

To start over from an empty database, `docker compose down -v` wipes the named volumes.

---

## Follow the data: the Polymarket example

The best way to understand the stack is to follow the pipeline end to end. Here's the trip the Polymarket dataset takes, from the chain to a dashboard and paid API endpoint.

### 1. Ingestion — getting the data out of the chain

Polymarket runs on Polygon. Every trade is an `OrderFilled` event emitted by its CTFExchange contracts. **[Tiders](https://github.com/yulesa/tiders)** fetches those contract logs, decodes them, and writes them to ClickHouse.

Two scripts live in [ingestion/polymarket/](ingestion/polymarket/):

- **[polymarket_exchange.py](ingestion/polymarket/polymarket_exchange.py)**:
    A Tiders pipeline, points a *provider* (HyperSync, SQD, or a plain RPC node) at the exchange contracts, decodes every event type in the ABI and writes one raw table per event into ClickHouse (e.g. `raw__polymarket__exchange__event__order_filled`). Detailed walkthrough in the file comments.

- **[polymarket_gamma_markets.py](ingestion/polymarket/polymarket_gamma_markets.py)**:
    Polymarket doesn't store market information onchain. The human-readable market ("Will X happen?", its outcomes, slug, open/closed flags) lives offchain in Polymarket's public Gamma API. This script looks at which token ids have shown up in trades, fetches just the missing markets, and writes them to `raw__polymarket__gamma__markets` in the DB. It's a regular Python fetch script.

Together they give you the two halves you need: *what happened onchain* and *what those trades mean*.

> A deeper dive into Tiders is covered in the [Tiders README](https://github.com/yulesa/tiders) and [docs](https://yulesa.github.io/tiders-docs/).

### 2. Transformation — turning raw data into meaningful tables

Raw event tables are faithful to the chain but don't reveal much on their own: hex-encoded ids, amounts in base units, no market names. The [dbt/](dbt/) project reshapes them in two more layers under the models folder:

- **`stg__…`** ([dbt/models/stg/](dbt/models/stg/)) — Mostly an organizational convenience, following best practices. Thin views over each raw table. Light typing and renaming, but no business logic. One per event, plus one for the Gamma markets.

- **`mart__…`** ([dbt/models/mart/](dbt/models/mart/)) — The business logic that leads to tables people actually want:
    - `mart__polymarket_v2__order_filled` — decoded CLOB fills with amounts in USD/contracts, derived price, and BUY/SELL side, one row per fill.
    - `mart__polymarket_v2__market_details` — per-token market metadata from the Gamma dump (question, outcome, slug, link, neg_risk, open/closed flags), one row per (market, outcome).
    - `mart__polymarket_v2__token_conditions` — slim `token_id → condition_id` mapping with the human-readable outcome, synthesized from the Gamma data.
    - `mart__polymarket_v2__trades` — the flagship table: every fill enriched with its off-chain market context (question text, outcome name, link, flags).
    - `mart__polymarket_v2__market_prices_hourly` — per-token hourly OHLC, VWAP, and volume aggregated over fills.
    - `mart__polymarket_v2__market_prices_daily` — the same OHLC/VWAP/volume aggregate rolled up to daily granularity.

The mart tables are the product. They're what the dashboard charts and what buyers download.

### 3. Dashboard — showing buyers what they'd get

Selling data is hard if nobody can see what's inside. The [Evidence](https://docs.evidence.dev/) project in [dashboards/polymarket_v2/](dashboards/polymarket_v2/) is a static site built from mart tables: KPIs, volume-over-time charts, top markets, top traders, a per-market explorer, and a dataset preview page. 

A [index](dashboards/index.html) file contains a static landing page with links to the multiple dashboards (this example has only one).

Evidence abstracts away most of the complexity of configuring charts and building a dashboard web page into simple, readable Markdown files:

- The [pages](dashboards/polymarket_v2/pages/) directory is mostly what you edit — it shapes the dashboard pages.
- The [sources](dashboards/polymarket_v2/sources/) directory holds the queries that pull from the database into the dashboard project and are referenced in the pages.

Two things make it more than a normal Evidence site:

- A [+layout.svelte](dashboards/polymarket_v2/pages/+layout.svelte) file overrides every page and adds a connect-wallet button at the top.
- It ships with an extra component, a **Tiders download button**. This connects the page to the paid API server (see below). Click it and the page calls the server's API; the server replies "that'll cost X", your wallet signs, and the CSV downloads.

Dashboards are static — they do not update live. Whenever the underlying data changes, rebuild the project (`make polymarket_v2-dashboard`) and the server picks up the new files automatically.

### 4. Server — serving the site and selling the data

[tiders-x402-server](https://github.com/yulesa/tiders-x402-server) is the front door. It does two jobs from one process:

- **Serves the dashboard** as a static site at a public URL.
- **Sells the mart tables** over an HTTP API. A buyer sends a SQL query; the server validates it, prices it, and replies `402 Payment Required`. The buyer's wallet signs a stablecoin payment via the [x402 protocol](https://x402.org), resends, and gets the results back as a fast Apache Arrow stream. The dashboard pages embed this through the **Tiders download button**, but users can also make direct API calls to the server.

Which tables are sold, and at what price, is set in [tiders-x402-server/tiders-x402-server.yaml](tiders-x402-server/tiders-x402-server.yaml) — this example charges per row on the six `mart__polymarket_v2__*` tables and points payments at the wallet in your `.env`.

> A detail explanation of tiders-x402-server is covered in the [README](https://github.com/yulesa/tiders-x402-server) and [docs](https://yulesa.github.io/tiders-x402-server/).

That's the full data loop.

### 5. Data orchestration — how to command every piece 

The root [Makefile](Makefile) orchestrates the per-project pipeline. Each project (here, just `polymarket_v2`) defines its stages (sequence of execution commands) in [projects/](projects/) folder.
All the stages in the pipeline are then manually triggered through an easier `make` commands.

```bash
make polymarket_v2            # run the full pipeline: ingest → dbt → dashboard
make polymarket_v2-ingest     # just pull fresh data
make polymarket_v2-dbt        # just rebuild the dbt models
make polymarket_v2-dashboard  # just rebuild the Evidence site
```

Two optional variables pass through to the underlying tools:

```bash
make polymarket_v2-ingest TO_BLOCK=22000000   # stop ingesting at a block
make polymarket_v2-ingest TARGET=prod         # run ingest, but write to the prod database, not dev (dev is default, to avoid accidental writes)
make polymarket_v2 TARGET=prod                # run all, writing to the prod database
```

Under the hood each stage is just a sequence of `docker compose exec` into the right container — the ingestion container for the Python scripts, the `dbt` container for the models, and a Node container for the dashboard build. The containers stay running idle, so re-running a stage is fast and needs no rebuild.

You can configure a new project by editing its make file in the [projects/](projects/) folder.

### 6. Cloudflare (Extra) — connecting the server to the web

The Quick Start runs everything locally. To put the dashboard and paid API on the internet without opening ports on your router, the stack includes a commented-out [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) service in [docker-compose.yaml](docker-compose.yaml):

1. Create a tunnel in the Cloudflare Zero Trust dashboard and point a public hostname at `http://tiders-server:4021`.
2. Put the tunnel token in `.env` as `TUNNEL_TOKEN`.
3. Uncomment the `cloudflared` service and `docker compose up -d`.

For a real deployment you'd also remove the `clickhouse` port mapping (so the database isn't reachable from outside the Docker network) and set `server.base_url` in the server config to your public hostname.


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

## Repository layout

```
.
├── docker-compose.yaml      # Configs the whole stack: ClickHouse, ingestion, dbt, server, dashboard builder
├── Makefile                 # orchestrates pipelines included in projects/*.mk
├── .env.example             # secrets and global configs (for copying)
│
├── clickhouse/              # (1) ClickHouse server-setting overrides
│
├── ingestion/               # (2) Tiders pipelines + Python scripts
│   └── polymarket/
│
├── dbt/                     # (3) transformation layer
│   └── models/
│       └── helpers/         # pre-made helper models
│       └── stg/             # staging models
│       └── mart/            # final product models
│
├── dashboards/              # (4) Evidence static sites
│   └── index.html           # Static website landing page
│   └── polymarket_v2/
│       └── pages/           # evidence web pages
│       └── sources/         # evidence data sources
│
├── tiders-x402-server/      # (5) server config + Dockerfile
│
└── projects/                # per-project Makefiles (one stage chain each)
    └── polymarket_v2.mk
```

---

## Adding your own dataset

The `polymarket_v2` project is a template. To index something else:

1. **Ingest** — add a script (Tiders pipeline or plain Python) under `ingestion/` that writes raw tables to ClickHouse.
2. **Transform** — add `stg__` and `mart__` models under `dbt/models/` for your new tables.
3. **Sell** — list the mart tables and their prices in the server's YAML config.
4. **Show** — scaffold a dashboard (`cd tiders-x402-server && tiders-x402-server dashboard <slug>`), then edit its pages.
5. **Wire it up** — add a `projects/<name>.mk` with `<name>-ingest`, `<name>-dbt`, and `<name>-dashboard` targets, and add `<name>` to `PROJECTS` in the [Makefile](Makefile).

Everything else — the database, the containers, the payment plumbing — you already have.
