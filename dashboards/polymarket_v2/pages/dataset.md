---
title: Explore the dataset
sidebar_position: 2
full_width: true
---
<Alert status="positive">
  This page showcases the <a href="https://github.com/yulesa/tiders-x402-server" target="_blank" rel="noopener" style="color: #2563eb; text-decoration: underline; font-weight: 600;">Tiders-x402-Server ↗</a> in action.

  To download the underlying tables, click the Tiders download button next each card or directly connect to the API — payment is handled via <a href="https://x402.org" target="_blank" rel="noopener" style="color: #2563eb; text-decoration: underline; font-weight: 600;">x402 ↗</a>.
</Alert>

<Alert status="negative">
  Data may be incorrect, outdated and don't represent full history of polymarket — treat paid downloads as a contribution to the project. Payments are non-refundable under any circumstances.
</Alert>

## Explore the full dataset

Everything in the other pages is built from aggregates over the full database.
The cards below let you preview each underlying mart table — five rows each — so
you can see exactly what schema you'd get if you bought it.

Tables are grouped by what they describe:

- **Trades** — every on-chain CLOB fill, both raw and enriched with market metadata.
- **Price rollups** — hourly and daily OHLC, VWAP, and volume per outcome token.
- **Reference data** — market metadata and the token → market/outcome mapping.

Each card has a **Download** button — payment is handled inline via x402 and you
pull the full dataset, not the 5-row preview.

### Trades

**Trades** — every CLOB fill enriched with market metadata: question, outcome, price, size, maker/taker, and transaction context.

```sql trades_preview
select * from clickhouse.mart__polymarket_v2__trades
```

<DataTable data={trades_preview} rows=5 compact=true formatColumnTitles=false downloadable=false />

<Grid cols=1>
  <TidersDownloadButton
    label="Tiders Download - Trades"
    filename="mart__polymarket_v2__trades.csv"
    query={`select * from mart__polymarket_v2__trades`}
  />
</Grid>

**Order filled** — raw per-event `OrderFilled` fills from the CTFExchange contract, before market enrichment.

```sql order_filled_preview
select * from clickhouse.mart__polymarket_v2__order_filled
```

<DataTable data={order_filled_preview} rows=5 compact=true formatColumnTitles=false downloadable=false />

<Grid cols=1>
  <TidersDownloadButton
    label="Tiders Download - Order Filled"
    filename="mart__polymarket_v2__order_filled.csv"
    query={`select * from mart__polymarket_v2__order_filled`}
  />
</Grid>

### Price rollups

**Hourly prices** — hourly OHLC, VWAP, and volume per outcome token.

```sql prices_hourly_preview
select * from clickhouse.mart__polymarket_v2__market_prices_hourly
```

<DataTable data={prices_hourly_preview} rows=5 compact=true formatColumnTitles=false downloadable=false />

<Grid cols=1>
  <TidersDownloadButton
    label="Tiders Download - Hourly Prices"
    filename="mart__polymarket_v2__market_prices_hourly.csv"
    query={`select * from mart__polymarket_v2__market_prices_hourly`}
  />
</Grid>

**Daily prices** — daily OHLC, VWAP, and volume per outcome token.

```sql prices_daily_preview
select * from clickhouse.mart__polymarket_v2__market_prices_daily
```

<DataTable data={prices_daily_preview} rows=5 compact=true formatColumnTitles=false downloadable=false />

<Grid cols=1>
  <TidersDownloadButton
    label="Tiders Download - Daily Prices"
    filename="mart__polymarket_v2__market_prices_daily.csv"
    query={`select * from mart__polymarket_v2__market_prices_daily`}
  />
</Grid>

### Reference data

**Market details** — per-token market metadata: question, outcome, slug/link, neg-risk flag, active/closed/archived flags, and start/end times.

```sql market_details_preview
select * from clickhouse.mart__polymarket_v2__market_details
```

<DataTable data={market_details_preview} rows=5 compact=true formatColumnTitles=false downloadable=false />

<Grid cols=1>
  <TidersDownloadButton
    label="Tiders Download - Market Details"
    filename="mart__polymarket_v2__market_details.csv"
    query={`select * from mart__polymarket_v2__market_details`}
  />
</Grid>

**Token conditions** — mapping of each outcome token to its condition, question, and outcome name.

```sql token_conditions_preview
select * from clickhouse.mart__polymarket_v2__token_conditions
```

<DataTable data={token_conditions_preview} rows=5 compact=true formatColumnTitles=false downloadable=false />

<Grid cols=1>
  <TidersDownloadButton
    label="Tiders Download - Token Conditions"
    filename="mart__polymarket_v2__token_conditions.csv"
    query={`select * from mart__polymarket_v2__token_conditions`}
  />
</Grid>
