---
title: Polymarket Analytics
full_width: true
---

```sql kpis
-- The ClickHouse connector returns DateTime as strings, so cast to timestamp
-- here (DuckDB) for Evidence to treat them as dates.
select * replace (
  first_trade::timestamp as first_trade,
  last_trade::timestamp as last_trade
) from clickhouse.overview_kpis
```

```sql status
select * from clickhouse.market_status
```

Data window: <Value data={kpis} column=first_trade fmt="hh:mm:ss" /> – <Value data={kpis} column=last_trade fmt="hh:mm:ss" /> UTC.

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
  <BigValue data={kpis} value=fees_usd fmt=num0 title="Total Fees" />
</Grid>


## Trading activity over time

```sql vbm
select * replace (minute::timestamp as minute) from clickhouse.volume_by_minute
```

<AreaChart
  data={vbm}
  x=minute
  y=volume_usd
  yFmt=usd0
  title="Volume traded per minute (USD)"
/>

<LineChart
  data={vbm}
  x=minute
  y={["trades","traders"]}
  title="Trades & unique traders per minute"
/>

## Top markets by volume

```sql top_markets
select * from clickhouse.top_markets
```

<BarChart
  data={top_markets.slice(0, 15)}
  x=question
  y=volume_usd
  yFmt=usd0
  swapXY=true
  title="Top 15 markets — traded volume (USD)"
/>

<DataTable data={top_markets} rows=15 search=true link=polymarket_link>
  <Column id=question title="Market" wrap=true />
  <Column id=volume_usd title="Volume" fmt=usd0 contentType=colorscale />
  <Column id=trades title="Trades" fmt=num0 />
  <Column id=traders title="Traders" fmt=num0 />
  <Column id=avg_price title="Avg price" fmt=pct1 />
</DataTable>

## Most active traders

```sql top_traders
select * from clickhouse.top_traders
```

<DataTable data={top_traders} rows=10>
  <Column id=trader title="Trader (taker)" />
  <Column id=volume_usd title="Volume" fmt=usd0 contentType=colorscale />
  <Column id=trades title="Trades" fmt=num0 />
  <Column id=markets_traded title="Markets" fmt=num0 />
</DataTable>

## Recent trades

```sql recent
select * replace (timestamp::timestamp as timestamp) from clickhouse.recent_trades
```

<DataTable data={recent} rows=15 search=true link=polymarket_link>
  <Column id=timestamp title="Time" fmt="hh:mm:ss" />
  <Column id=question title="Market" wrap=true />
  <Column id=outcome title="Outcome" />
  <Column id=amount_usd title="Amount" fmt=usd2 />
  <Column id=shares title="Shares" fmt=num1 />
  <Column id=price title="Price" fmt=pct1 />
</DataTable>

<TidersDownloadButton
  label="Download recent trades"
  filename="polymarket_recent_trades.csv"
  query={`select timestamp, question, token_outcome as outcome, amount as amount_usd, shares, price, taker from tiders.mart__polymarket_v2__trades where question is not null order by timestamp desc limit 5000`}
/>

[Explore an individual market →](/markets)
