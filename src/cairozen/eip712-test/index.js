import { keccak256 } from "viem";
import {uint256, hash} from 'starknet'

const typeHash = keccak256(`Call(bytes32 to, bytes32 selector, bytes32[] calldata)`);
const domainTypeHash = keccak256('EIP712Domain(string name,uint256 version,uint256 chainId)');
const structHash = keccak256(typeHash+'05d4f1ba301559254a7769068cceb2db6291b2cf83d79f52e3755145e9c322da'+'0x30f842021fbf02caf80d09a113997c1e00a32870eee0c6136bed27acb348bea'+'00000000000000000000000000000000000000000000000000000000000003e8000000000000000000000000000000000000000000000000000000000000029b');
console.log(structHash, uint256.uint256ToBN({
    low: 315532035679662642287971556268204731212,
    high: 204596012861305909332609812918893612606
}).toString(16), hash.starknetKeccak(100).toString(16))
