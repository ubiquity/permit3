// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Permit3} from "src/Permit3.sol";

bytes32 constant PERMIT3_SALT = bytes32(uint256(0x0000000000000000000000000000000000000000d3af2663da51c10215000000));

contract DeployPermit3 is Script {
    function setUp() public {}

    function run() public returns (Permit3 permit3) {
        address[] memory owners = new address[](0);
        uint256[] memory wordPositions = new uint256[](0);
        uint256[] memory masks = new uint256[](0);

        vm.startBroadcast();

        permit3 = new Permit3{salt: PERMIT3_SALT}(owners, wordPositions, masks, "Permit3");
        console2.log("Permit3 Deployed:", address(permit3));

        vm.stopBroadcast();
    }
}
