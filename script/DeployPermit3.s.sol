// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/console2.sol";
import "forge-std/Script.sol";
import {Permit3} from "src/Permit3.sol";

bytes32 constant PERMIT3_SALT = bytes32(uint256(0x0000000000000000000000000000000000000000d3af2663da51c10215000000));

contract DeployPermit3 is Script {
    function setUp() public {}

    function run() public returns (Permit3 permit3) {
        Permit3.NonceImport[] memory imports = _initialNonceImports();
        string memory version = vm.envOr("PERMIT3_VERSION", string(""));

        vm.startBroadcast();

        permit3 = new Permit3{salt: PERMIT3_SALT}(imports, version);
        console2.log("Permit3 Deployed:", address(permit3));
        console2.log("Permit3 Version:", version);

        vm.stopBroadcast();
    }

    /// @notice Override or edit this method before deployment to import already-used nonce bitmaps.
    /// @dev Each mask is ORed into nonceBitmap[owner][wordPos] by the Permit3 constructor.
    function _initialNonceImports() internal pure virtual returns (Permit3.NonceImport[] memory imports) {
        imports = new Permit3.NonceImport[](0);
    }
}
