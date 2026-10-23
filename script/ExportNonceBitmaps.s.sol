// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {ISignatureTransfer} from "src/interfaces/ISignatureTransfer.sol";

/// @notice Reads used unordered nonce bitmap words from an existing Permit2/Permit3 deployment.
/// @dev Use the printed `(owner, wordPos, bitmap)` tuples as `Permit3.NonceBitmapImport` inputs.
/// Example:
///   forge script script/ExportNonceBitmaps.s.sol \
///     --sig "run(address,address,uint256[])" 0x000000000022D473030F116dDEE9F6B43aC78BA3 0xOwner "[0,1,2]" \
///     --rpc-url $MAINNET_RPC_URL
contract ExportNonceBitmaps is Script {
    function run(address permit, address owner, uint256[] calldata wordPositions) public view {
        ISignatureTransfer source = ISignatureTransfer(permit);

        console2.log("source", permit);
        console2.log("owner", owner);
        console2.log("wordPositions", wordPositions.length);

        for (uint256 i = 0; i < wordPositions.length; ++i) {
            uint256 wordPos = wordPositions[i];
            uint256 bitmap = source.nonceBitmap(owner, wordPos);

            if (bitmap != 0) {
                console2.log("import", owner, wordPos, bitmap);
            }
        }
    }
}
