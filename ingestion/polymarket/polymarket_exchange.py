# =============================================================================
# Polymarket Exchanges events
# =============================================================================
#
# Usage:
#   docker compose exec tiders-ingestion python polymarket/polymarket_exchange.py

import asyncio
import os
from pathlib import Path
from typing import Optional

import clickhouse_connect
import requests
from dotenv import load_dotenv

load_dotenv(Path(__file__).parent / ".env")

from tiders import config as cc  # noqa: E402
from tiders import run_pipeline  # noqa: E402
from tiders.config import CheckpointConfig  # noqa: E402
from tiders_core import evm_abi_events, ingest  # noqa: E402


DEFAULT_HYPERSYNC_URL = "https://polygon.hypersync.xyz/"
DEFAULT_SQD_URL = "https://portal.sqd.dev/datasets/polygon-mainnet"
DEFAULT_RPC_URL = "https://polygon.gateway.tenderly.co"

POLYMARKET_EXCHANGE_RAW_LOGS_TABLE = "raw__polymarket__exchange__raw_logs"
DEPLOY_BLOCK = 33605403  # earliest deploy block among the 2 exchanges contracts
BLOCKS_TABLE = "raw__polygon__blocks"

# Polygon mainnet averages ~2s per block, so 12h ≈ 21,600 blocks back from
# the current chain head.
LOOKBACK_SECONDS = 1 * 60 * 60
POLYGON_BLOCK_TIME_SECONDS = 2
LOOKBACK_BLOCKS = LOOKBACK_SECONDS // POLYGON_BLOCK_TIME_SECONDS


def _fetch_chain_head(rpc_url: str) -> int:
    """Return the current chain head block number via eth_blockNumber."""
    resp = requests.post(
        rpc_url,
        json={"jsonrpc": "2.0", "id": 1, "method": "eth_blockNumber", "params": []},
        timeout=15,
    )
    resp.raise_for_status()
    payload = resp.json()
    if "error" in payload:
        raise RuntimeError(f"eth_blockNumber failed: {payload['error']}")
    return int(payload["result"], 16)

POLYMARKET_EXCHANGE_ADDRESSES = [
    "0xe111180000d2663c0091e4f400237545b87b996b",  # polymarket_CTFExchange
    "0xe2222d279d744050d28e00520010520000310f59"   # polymarket_CTFExchange
]

_POLYMARKET_EXCHANGE_ABI_JSON = (Path(__file__).parent / "abi" / "polymarket_exchange.abi.json").read_text()
exchange_events = {
    ev.name: {
        "topic0": ev.topic0,
        "signature": ev.signature,
        "name_snake_case": ev.name_snake_case,
        "selector_signature": ev.selector_signature,
        "abi_json": ev.abi_json,
    }
    for ev in evm_abi_events(_POLYMARKET_EXCHANGE_ABI_JSON)
    
}


def create_provider(
    kind: ingest.ProviderKind,
) -> ingest.ProviderConfig:
    """Build a ProviderConfig for the given provider kind."""
    if kind == ingest.ProviderKind.HYPERSYNC:
        return ingest.ProviderConfig(
            kind=kind,
            url=DEFAULT_HYPERSYNC_URL,
            bearer_token=os.environ.get("BEARER_TOKEN"),
            stop_on_head=True,
        )
    if kind == ingest.ProviderKind.SQD:
        return ingest.ProviderConfig(
            kind=kind,
            url=DEFAULT_SQD_URL,
            bearer_token=os.environ.get("BEARER_TOKEN"),
            stop_on_head=True,
        )
    return ingest.ProviderConfig(
        kind=kind,
        url=os.environ.get("RPC_URL", DEFAULT_RPC_URL),
        bearer_token=os.environ.get("BEARER_TOKEN"),
        stop_on_head=True,
    )


def _polymarket_exchange_event_steps() -> list[cc.Step]:
    """Build the transformation steps for decoding all polymarket exchange event types at once."""
    steps: list[cc.Step] = []

    # CTF `tokenId` is a uint256 spread across the full keccak256 range, so
    # it cannot be stored losslessly in Decimal256 (signed Int256 underneath).
    # Re-encode just that column as raw 32-byte binary after decoding; the
    # HEX_ENCODE step at the end of the pipeline then turns it into a
    # 0x-prefixed hex string.
    TOKEN_ID_EVENTS = {"OrderFilled", "OrdersMatched"}

    for name, event in exchange_events.items():
        output_table = f"raw__polymarket__exchange__event__{event['name_snake_case']}"
        steps.append(
            cc.Step(
                kind=cc.StepKind.EVM_DECODE_EVENTS,
                config=cc.EvmDecodeEventsConfig(
                    event_signature=event["abi_json"],
                    input_table=POLYMARKET_EXCHANGE_RAW_LOGS_TABLE,
                    output_table=output_table,
                    allow_decode_fail=False,
                    filter_by_topic0=True,
                ),
            ),
        )
        if name in TOKEN_ID_EVENTS:
            steps.append(
                cc.Step(
                    kind=cc.StepKind.LARGE_INT_COLUMNS_TO_BINARY,
                    config=cc.LargeIntColumnsToBinaryConfig(
                        table_name=output_table,
                        columns=["tokenId"],
                    ),
                ),
            )

    steps.append(
        cc.Step(
            name="join_blocks_data",
            kind=cc.StepKind.JOIN_BLOCK_DATA,
            config=cc.JoinBlockDataConfig(
                block_table_name=BLOCKS_TABLE
                ),
        )
    )
    steps.append(
        cc.Step(
            kind=cc.StepKind.HEX_ENCODE,
            config=cc.HexEncodeConfig(),
        )
    )

    return steps


async def main(
    provider_kind: ingest.ProviderKind,
    to_block: Optional[int],
    target: str = "dev",
):
    db_env_var = "CLICKHOUSE_DB" if target == "prod" else "CLICKHOUSE_DEV_DB"
    client = await clickhouse_connect.get_async_client(
        host=os.environ.get("CLICKHOUSE_HOST", "localhost"),
        port=int(os.environ.get("CLICKHOUSE_PORT", "8123")),
        username=os.environ.get("CLICKHOUSE_USER", "default"),
        password=os.environ.get("CLICKHOUSE_PASSWORD", "default"),
        database=os.environ.get(db_env_var, "default"),
        secure=os.environ.get("CLICKHOUSE_SECURE", "false").lower() == "true",
    )

    provider = create_provider(provider_kind)
    writer = cc.Writer(
        kind=cc.WriterKind.CLICKHOUSE,
        config=cc.ClickHouseWriterConfig(client=client),
    )

    checkpoint = CheckpointConfig(
        table=POLYMARKET_EXCHANGE_RAW_LOGS_TABLE,       # table to read the max block from
        column="block_number",   # default, can be omitted
        writer_index=0,          # default, can be omitted
    )

    head = _fetch_chain_head(os.environ.get("RPC_URL", DEFAULT_RPC_URL))
    if head <= 87515408:
        raise RuntimeError(
            f"eth_blockNumber returned implausible head={head}; "
            f"refusing to backfill from DEPLOY_BLOCK"
        )
    from_block = head - LOOKBACK_BLOCKS

    print(
        f"[polymarket__exchange__events.py] Running polymarket exchange events query "
        f"for {len(POLYMARKET_EXCHANGE_ADDRESSES)} exchange addresses "
        f"(head={head}, from_block={from_block}, lookback={LOOKBACK_BLOCKS} blocks ≈ 12h)"
    )

    query = ingest.Query(
        kind=ingest.QueryKind.EVM,
        params=ingest.evm.Query(
            from_block=from_block,
            to_block=to_block,
            logs=[
                ingest.evm.LogRequest(
                    address=POLYMARKET_EXCHANGE_ADDRESSES,
                    include_blocks=True,
                )
            ],
            fields=ingest.evm.Fields(
                log=ingest.evm.LogFields(
                    block_number=True,
                    block_hash=True,
                    transaction_hash=True,
                    log_index=True,
                    address=True,
                    topic0=True,
                    topic1=True,
                    topic2=True,
                    topic3=True,
                    data=True,
                ),
                block=ingest.evm.BlockFields(
                    timestamp=True,
                    number=True,
                ),
            ),
        ),
    )

    pipeline = cc.Pipeline(
        provider=provider,
        query=query,
        writer=writer,
        checkpoint=checkpoint,
        table_aliases=cc.EvmTableAliases(logs=POLYMARKET_EXCHANGE_RAW_LOGS_TABLE, blocks=BLOCKS_TABLE),
        steps=_polymarket_exchange_event_steps(),
    )

    await run_pipeline(pipeline=pipeline)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--to-block", type=int, default=None)
    parser.add_argument("--target", type=str, default="dev")
    args = parser.parse_args()

    provider_kind = ingest.ProviderKind(os.environ.get("INGESTION_PROVIDER", "rpc"))
    # to_block_raw = os.environ.get("INGESTION_TO_BLOCK")
    # to_block = int(to_block_raw) if to_block_raw else None
    to_block = int(args.to_block) if args.to_block is not None else None

    print(
        f"[polymarket__exchange__events.py] Running with provider: {provider_kind}, to_block: {to_block}, target: {args.target}"
    )
    asyncio.run(main(provider_kind, to_block, args.target))
