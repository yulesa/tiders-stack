---
title: Polymarket Analytics
full_width: true
---
<Alert status="positive">
  This page showcases the <a href="https://github.com/yulesa/tiders-x402-server" target="_blank" rel="noopener" style="color: #2563eb; text-decoration: underline; font-weight: 600;">Tiders-x402-Server ↗</a> in action.

  To download the underlying tables, click the Tiders download button next to some datasets, check the "Explore the dataset" page, or directly connect to the API — payment is handled via <a href="https://x402.org" target="_blank" rel="noopener" style="color: #2563eb; text-decoration: underline; font-weight: 600;">x402 ↗</a>.
</Alert>

<Alert status="negative">
  Data may be incorrect, outdated and don't represent full history of polymarket — treat paid downloads as a contribution to the project. Payments are non-refundable under any circumstances.
</Alert>

```sql kpis
-- The ClickHouse connector returns DateTime as strings, so cast to timestamp
-- here (DuckDB) for Evidence to treat them as dates.
select
  volume_usd,
  trades,
  traders,
  markets,
  fees_usd,
  first_trade::timestamp as first_trade,
  last_trade::timestamp as last_trade
from clickhouse.overview_kpis
```

```sql status
select
  total_markets,
  active_markets,
  closed_markets,
  neg_risk_tokens
from clickhouse.market_status
```

Data window: <Value data={kpis} column=first_trade fmt="yyyy/mm/dd hh:mm:ss" /> – <Value data={kpis} column=last_trade fmt="yyyy/mm/dd hh:mm:ss" /> UTC.

<Grid cols=4>
  <BigValue data={kpis} value=volume_usd fmt=usd2m title="Traded volume" />
  <BigValue data={kpis} value=trades fmt=num0 title="Trades" />
  <BigValue data={kpis} value=traders fmt=num0 title="Unique traders" />
  <BigValue data={kpis} value=markets fmt=num0 title="Markets traded" />
</Grid>

<Grid cols=4>
  <BigValue data={status} value=total_markets fmt=num0 title="Markets in catalogue" />
  <BigValue data={status} value=active_markets fmt=num0 title="Active markets" />
  <BigValue data={status} value=closed_markets fmt=num0 title="Closed markets" />
  <BigValue data={kpis} value=fees_usd fmt=usd0 title="Total Fees" />
</Grid>


## Trading activity over time

```sql vbm
select
  minute::timestamp as minute,
  volume_usd,
  trades,
  traders
from clickhouse.volume_by_minute
```

<AreaChart
  data={vbm}
  x=minute
  y=volume_usd
  yFmt=usd0
  xFmt="mmm d, hh:mm"
  downloadableData=false
  title="Volume traded per minute (USD)"
/>

<LineChart
  data={vbm}
  x=minute
  y={["trades","traders"]}
  xFmt="mmm d, hh:mm"
  downloadableData=false
  title="Trades & unique traders per minute"
/>

## Top markets by volume

```sql top_markets
select
  question,
  volume_usd,
  trades,
  traders,
  avg_price,
  polymarket_link
from clickhouse.top_markets
```

<BarChart
  data={top_markets.slice(0, 15)}
  x=question
  y=volume_usd
  yFmt=usd0
  swapXY=true
  downloadableData=false
  title="Top 15 markets — traded volume (USD)"
/>

<DataTable data={top_markets} rows=15 search=true link=polymarket_link>
  <Column id=question title="Market" wrap=true />
  <Column id=volume_usd title="Volume" fmt=usd0 contentType=colorscale />
  <Column id=trades title="Trades" fmt=num0 />
  <Column id=traders title="Traders" fmt=num0 />
  <Column id=avg_price title="Avg price" fmt=usd2 />
</DataTable>

## Most active traders

```sql top_traders
select
  trader,
  volume_usd,
  trades,
  markets_traded
from clickhouse.top_traders
```

<DataTable data={top_traders} rows=10>
  <Column id=trader title="Trader (taker)" />
  <Column id=volume_usd title="Volume" fmt=usd0 contentType=colorscale />
  <Column id=trades title="Trades" fmt=num0 />
  <Column id=markets_traded title="Markets" fmt=num0 />
</DataTable>

## Recent trades

```sql recent
select
  timestamp::timestamp as timestamp,
  question,
  outcome,
  amount_usd,
  shares,
  price,
  polymarket_link
from clickhouse.recent_trades
order by amount_usd DESC
```

<DataTable data={recent} rows=15 search=true link=polymarket_link>
  <Column id=timestamp title="Time" fmt="hh:mm:ss" />
  <Column id=question title="Market" wrap=true />
  <Column id=outcome title="Outcome" />
  <Column id=amount_usd title="Amount" fmt=usd2 />
  <Column id=shares title="Shares" fmt=num1 />
  <Column id=price title="Price" fmt=usd2 />
</DataTable>

<TidersDownloadButton
  label="Download recent trades"
  filename="polymarket_recent_trades.csv"
  query={`select * from mart__polymarket_v2__trades order by amount desc limit 5000`}
/>

[Explore an individual market →](/markets)

[Explore the full dataset →](/dataset)
