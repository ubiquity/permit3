// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Permit3} from "src/Permit2.sol";
import {ISignatureTransfer} from "src/interfaces/ISignatureTransfer.sol";

bytes32 constant SALT = bytes32(uint256(0x0000000000000000000000000000000000000000d3af2663da51c10215000000));

contract DeployPermit2 is Script {
    function setUp() public {}

    function run() public returns (Permit3 permit3) {
        string memory nonceImportsPath = vm.envOr("NONCE_IMPORTS_PATH", string(""));
        ISignatureTransfer.NonceImport[] memory nonceImports = bytes(nonceImportsPath).length == 0
            ? new ISignatureTransfer.NonceImport[](0)
            : abi.decode(vm.parseJson(vm.readFile(nonceImportsPath)), (ISignatureTransfer.NonceImport[]));
        string memory versionNote = vm.envOr("VERSION_NOTE", string(""));

        vm.startBroadcast();

        permit3 = new Permit3{salt: SALT}(nonceImports, versionNote);
        console2.log("Permit3 Deployed:", address(permit3));

        vm.stopBroadcast();
    }
}
