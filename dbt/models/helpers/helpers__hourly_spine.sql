{{
    config(
        materialized = 'view',
    )
}}

SELECT
    arrayJoin(
        arrayMap(
            x -> toDateTime('2008-01-01 00:00:00') + toIntervalHour(x),
            range(
                toUInt32(
                    dateDiff('hour', toDateTime('2008-01-01 00:00:00'), toDateTime('2035-12-31 23:00:00')) + 1
                )
            )
        )
    ) AS hour
