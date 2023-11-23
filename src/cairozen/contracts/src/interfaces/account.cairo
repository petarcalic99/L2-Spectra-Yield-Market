use array::ArrayTrait;
use array::SpanTrait;
use starknet::ContractAddress;

#[derive(Serde, Drop)]
struct Call {
    to: ContractAddress,
    selector: felt252,
    calldata: Array<felt252>
}
