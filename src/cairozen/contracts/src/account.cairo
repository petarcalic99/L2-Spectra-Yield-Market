use core::clone::Clone;
const TRANSACTION_VERSION: felt252 = 1;
// 2**128 + TRANSACTION_VERSION
const QUERY_VERSION: felt252 = 340282366920938463463374607431768211457;
// keccak256(EIP712Domain(string name,uint256 version,uint256 chainId))
const DOMAIN_TYPEHASH: u256 = 0x5f12a0dcae00d34ac0cfbe4a162ec40900ab4f4f0239fb5bfd2ef745d3642742;
const NAME_HASH: u256 = 0xc500efc095cc80e1d1eea4b01f685c560682d5b4ac61bb04545c1c9a0b0e0cd8;
const VERSION_HASH: u256 = 0xd6cd7e1ecacaaef4103061f1a1d196fcfbebfbbf4315f4c1fe0112a9cb29675f;
const CHAIN_ID: u256 = 0x0000000000000000000000000000000000000000000000534e5f474f45524c49;
const DOMAIN_SEPARATOR: u256 = 0xba922de6f28a112afc4a6807ed682e6a601640895954bb1fa6732fe1fa092620;
// keccak256(Call(bytes32 to, bytes32 selector, bytes32[] calldata))
const CALL_TYPEHASH: u256 = 0xba8a93bf612e0f508ec43785bca3407b1ef23e08d896674e0fb7036081b770d4;

use contracts::interfaces::account::Call;
use array::ArrayTrait;
use array::SpanTrait;

#[abi]
trait AccountABI {
    #[external]
    fn __execute__(calls: Array<Call>);
    #[external]
    fn __validate__(calls: Array<Call>) -> felt252;
    #[external]
    fn __validate_declare__(class_hash: felt252) -> felt252;
    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _public_key: felt252
    ) -> felt252;
    #[view]
    fn get_eth_address() -> felt252;
    #[view]
    fn is_valid_signature(hash: u256, signature: Array<felt252>) -> u32;
}


#[account_contract]
mod CairozenEOA {
    use super::TRANSACTION_VERSION;
    use super::QUERY_VERSION;
    use contracts::interfaces::account::Call;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_tx_info;
    use starknet::call_contract_syscall;
    use starknet::secp256_trait::{verify_eth_signature_u32, Secp256PointTrait};
    use starknet::secp256k1::{Secp256k1Point, Secp256k1PointImpl};
    use zeroable::Zeroable;
    use box::BoxTrait;
    use array::ArrayTrait;
    use array::SpanTrait;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use starknet::EthAddress;
    use integer::u256_from_felt252;
    use integer::u32_to_felt252;
    use starknet::contract_address_to_felt252;
    use super::CALL_TYPEHASH;
    use starknet::{Felt252TryIntoEthAddress};

    struct Storage {
        owner: felt252
    }

    #[constructor]
    fn constructor(_owner: felt252) {
        owner::write(_owner);
    }


    /// Getters

    #[view]
    fn get_eth_address() -> felt252 {
        owner::read()
    }

    #[view]
    fn is_valid_signature(hash: u256, signature: Array<felt252>) -> felt252 {
        assert(signature.len() == 3_u32, 'invalid signature length!');

        let v = *signature[0_u32];
        let r = *signature[1_u32];
        let s = *signature[2_u32];

        let v_u32: u32 = v.try_into().unwrap();
        let r_u256: u256 = r.into();
        let s_u256: u256 = s.into();

        is_valid_eth_signature(hash, r_u256, s_u256, v_u32);
        starknet::VALIDATED
    }

    #[external]
    fn __execute__(mut calls: Array<Call>) {
        let sender = get_caller_address();
        assert(sender.is_zero(), 'Account: invalid caller');
        let tx_info = get_tx_info().unbox();
        let version = tx_info.version;
        if version != TRANSACTION_VERSION {
            assert(version == QUERY_VERSION, 'Account: invalid tx version');
        }
        loop {
            match calls.pop_front() {
                Option::Some(call) => {
                    starknet::call_contract_syscall(call.to, call.selector, call.calldata.span())
                        .unwrap_syscall();
                },
                Option::None(_) => {
                    break ();
                },
            };
        };
    }

    #[external]
    fn __validate__(mut calls: Array<Call>, msg_hash: u256) -> felt252 {
        let tx_info = get_tx_info().unbox();
        let signature = tx_info.signature;
        assert(signature.len() == 3_u32, 'invalid signature length!');

        let v = *signature[0_u32];
        let r = *signature[1_u32];
        let s = *signature[2_u32];

        let v_u32: u32 = v.try_into().unwrap();
        let r_u256: u256 = r.into();
        let s_u256: u256 = s.into();

        is_valid_eth_signature(msg_hash, r_u256, s_u256, v_u32)
    }

    #[external]
    fn __validate_declare__(class_hash: felt252, msg_hash: u256) -> felt252 {
        let tx_info = get_tx_info().unbox();
        let signature = tx_info.signature;
        assert(signature.len() == 3_u32, 'invalid signature length!');
        let v = *signature[0_u32];
        let r = *signature[1_u32];
        let s = *signature[2_u32];

        let v_u32: u32 = v.try_into().unwrap();
        let r_u256: u256 = r.into();
        let s_u256: u256 = s.into();

        is_valid_eth_signature(msg_hash, r_u256, s_u256, v_u32)
    }

    #[external]
    fn __validate_deploy__(
        class_hash: felt252, contract_address_salt: felt252, _owner: EthAddress
    ) -> felt252 {
        starknet::VALIDATED
    }
    /// INTERNAL FUNCTIONS

    fn is_valid_eth_signature(msg_hash: u256, r: u256, s: u256, v: u32) -> felt252 {
        let eth_address_felt252 = get_eth_address();

        let eth_address : EthAddress = eth_address_felt252.try_into().unwrap();

        //verify_eth_signature_u32::<Secp256k1Point>(:msg_hash, :r, :s, :v, :eth_address);

        starknet::VALIDATED
    }
}
