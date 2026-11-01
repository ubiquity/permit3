// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Permit3} from "src/Permit3.sol";
import {IPermit3} from "src/interfaces/IPermit3.sol";

contract DeployPermit3 is Script {
    bytes32 internal constant SALT = bytes32(uint256(0xd3af2663da51c10215000000));

    function run(address owner, string memory version, IPermit3.NonceImport[] memory nonces)
        public
        returns (Permit3 permit3)
    {
        vm.startBroadcast();
        permit3 = new Permit3{salt: SALT}(owner, version, nonces);
        console2.log("Permit3 Deployed:", address(permit3));
        vm.stopBroadcast();
    }
}
