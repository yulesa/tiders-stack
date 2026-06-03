{{ config(materialized='view') }}

SELECT
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    topic0,
    topic1,
    topic2,
    topic3,
    data,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__raw_logs
