from starkware.cairo.lang.vm.crypto import pedersen_hash
from starkware.cairo.common.hash_state import compute_hash_on_elements
from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
from typing import List


def calculate_transaction_hash_common(
    tx_hash_prefix,
    version,
    contract_address,
    entry_point_selector,
    calldata,
    max_fee,
    chain_id,
    additional_data,
    hash_function=pedersen_hash,
) -> int:
    calldata_hash = compute_hash_on_elements(data=calldata, hash_func=hash_function)
    data_to_hash = [
        tx_hash_prefix,
        version,
        contract_address,
        entry_point_selector,
        calldata_hash,
        max_fee,
        chain_id,
        *additional_data,
    ]

    return compute_hash_on_elements(
        data=data_to_hash,
        hash_func=hash_function,
    )


def tx_hash_from_message(
    from_address: str, to_address: int, selector: int, nonce: int, payload: List[int]
) -> str:
    int_hash = calculate_transaction_hash_common(
        tx_hash_prefix=510926345461491391292786,    # int.from_bytes(b"l1_handler", "big")
        version=0,
        contract_address=to_address,
        entry_point_selector=selector,
        calldata=[int(from_address, 16), *payload],
        max_fee=0,
        chain_id=1536727068981429685321,  # StarknetChainId.TESTNET.value
        additional_data=[nonce],
    )
    return hex(int_hash)


print(
    tx_hash_from_message(
        from_address="0xdc03b0028e3afa0cb865c28e6c57f0a3a77c5cd7",
        to_address=1288861057681573168267271242332914037939928261850385863052822792441744683451,
        selector=656059555830309884025984481032325730537460019592461379540739705017927077473,
        nonce=756645,
        payload=[
            2930266564062182357406610323500398021706613129656897641475375789725703676161,
            10000,
            86400,
            2000,
            1000
        ],
    )
)
