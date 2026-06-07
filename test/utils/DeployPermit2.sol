// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {Permit2} from "../../src/Permit2.sol";

/// @notice Helper to deploy the current Permit2 compatibility wrapper for tests.
contract DeployPermit2 is Script {
    function deployPermit2() public returns (address) {
        return run();
    }

    function run() public returns (address) {
        return address(new Permit2());
    }
}
