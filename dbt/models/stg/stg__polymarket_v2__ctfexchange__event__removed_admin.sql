{{ config(materialized='view') }}

SELECT
    removedAdmin AS removed_admin,
    admin,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__removed_admin
