{{ config(materialized='view') }}

SELECT
    maxFeeRate AS max_fee_rate,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__max_fee_rate_updated
