{{ config(materialized='view') }}

SELECT
    user,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__user_unpaused
