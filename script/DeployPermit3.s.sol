// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Permit3} from "src/Permit3.sol";

bytes32 constant PERMIT3_SALT = bytes32(uint256(0x0000000000000000000000000000000000000000d3af2663da51c10215000003));

contract DeployPermit3 is Script {
    function setUp() public {}

    function run() public returns (Permit3 permit3) {
        Permit3.NonceBitmapImport[] memory emptyImports = new Permit3.NonceBitmapImport[](0);

        vm.startBroadcast();

        permit3 = new Permit3{salt: PERMIT3_SALT}(emptyImports, "3.0.0", "", msg.sender);
        console2.log("Permit3 Deployed:", address(permit3));

        vm.stopBroadcast();
    }
}
