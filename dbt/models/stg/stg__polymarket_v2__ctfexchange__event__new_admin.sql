{{ config(materialized='view') }}

SELECT
    newAdminAddress AS new_admin_address,
    admin,
    block_number,
    block_hash,
    transaction_hash,
    log_index,
    address,
    toDateTime(toUInt64(timestamp)) AS timestamp
FROM raw__polymarket__exchange__event__new_admin
