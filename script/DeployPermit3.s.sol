// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {Permit3} from "src/Permit3.sol";
import {SignatureTransfer} from "src/SignatureTransfer.sol";

contract DeployPermit3 is Script {
    bytes32 public constant SALT = bytes32(uint256(0x0000000000000000000000000000000000000000000000000000000000000000));

    function run() public returns (Permit3 permit3) {
        vm.startBroadcast();
        SignatureTransfer.NonceBitmapImport[] memory nonceImports = new SignatureTransfer.NonceBitmapImport[](0);
        permit3 = new Permit3{salt: SALT}(nonceImports, "initial Permit3 deployment");
        console2.log("Permit3 Deployed:", address(permit3));
        vm.stopBroadcast();
    }
}
