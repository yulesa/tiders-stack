---
title: Market Explorer
full_width: true
---

Pick a market to inspect its price action, outcomes and recent trades. The list
covers the 300 highest-volume markets in the data window.

```sql markets
select condition_id, question, volume_usd from clickhouse.top_markets order by volume_usd desc
```

<Dropdown
  name=market
  data={markets}
  value=condition_id
  label=question
  title="Market"
  defaultValue={markets[0].condition_id}
/>

```sql market_kpi
select * from clickhouse.top_markets where condition_id = '${inputs.market.value}'
```

## <Value data={market_kpi} column=question />

<Grid cols=4>
  <BigValue data={market_kpi} value=volume_usd fmt=usd0 title="Volume" />
  <BigValue data={market_kpi} value=trades fmt=num0 title="Trades" />
  <BigValue data={market_kpi} value=traders fmt=num0 title="Traders" />
  <BigValue data={market_kpi} value=avg_price fmt=pct1 title="Avg price" />
</Grid>

<LinkButton url={market_kpi[0]?.polymarket_link}>View on Polymarket ↗</LinkButton>

## Outcome price over time

```sql prices
select minute::timestamp as minute, outcome, price, volume_usd, trades
from clickhouse.market_minute_prices
where condition_id = '${inputs.market.value}'
order by minute
```

<LineChart
  data={prices}
  x=minute
  y=price
  series=outcome
  yFmt=pct0
  yMin=0
  yMax=1
  title="VWAP price by outcome (implied probability)"
/>

<BarChart
  data={prices}
  x=minute
  y=volume_usd
  series=outcome
  yFmt=usd0
  title="Volume per minute by outcome (USD)"
/>

## Recent trades in this market

```sql market_trades
select timestamp::timestamp as timestamp, outcome, amount_usd, shares, price, taker
from clickhouse.market_recent_trades
where condition_id = '${inputs.market.value}'
order by timestamp desc
```

<DataTable data={market_trades} rows=20 search=true>
  <Column id=timestamp title="Time" fmt="hh:mm:ss" />
  <Column id=outcome title="Outcome" />
  <Column id=amount_usd title="Amount" fmt=usd2 />
  <Column id=shares title="Shares" fmt=num1 />
  <Column id=price title="Price" fmt=pct1 />
  <Column id=taker title="Taker" />
</DataTable>

<TidersDownloadButton
  label="Download this market's trades"
  filename="polymarket_market_trades.csv"
  query={`select timestamp, token_outcome as outcome, amount as amount_usd, shares, price, taker from tiders.mart__polymarket_v2__trades where condition_id = '${inputs.market.value}' order by timestamp desc`}
/>
