---
title: Polymarket
full_width: true
---

```sql sample
select * from clickhouse.raw__ethereum__token_metadata limit 100
```

This dashboard was scaffolded by tiders-x402-server with command `tiders-x402-server dashboard`.

<DataTable data={sample} rows=10 />

<TidersDownloadButton
  label="Download sample"
  filename="raw__ethereum__token_metadata.csv"
  query={`select * from raw__ethereum__token_metadata limit 1`}
/>
