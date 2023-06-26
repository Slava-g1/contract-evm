// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

library Utils {
    function getAccountId(address addr, string calldata brokerRaw) internal pure returns (bytes32 accountId) {
        // get brokerId from brokerRaw
        bytes32 brokerHash = string2HashedBytes32(brokerRaw);
        // call `getAccountId(address,bytes32)`
        accountId = getAccountId(addr, brokerHash);
    }

    function getAccountId(address addr, bytes32 brokerHash) internal pure returns (bytes32 accountId) {
        // data is encode addr + brokerId
        bytes memory data = abi.encode(addr, brokerHash);
        // accountId is keccak data
        accountId = keccak256(data);
    }

    // string to bytes32, equal to etherjs `ethers.encodeBytes32String('source')`
    function string2Bytes32(string memory source) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }

    // string to keccack bytes32
    function string2HashedBytes32(string memory source) internal pure returns (bytes32) {
        return keccak256(abi.encode(string2Bytes32(source)));
    }
}
