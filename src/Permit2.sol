// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Permit3} from "./Permit3.sol";
import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";

/// @notice Backwards-compatible alias for integrations that still import Permit2.
/// @dev New deployments should use Permit3 directly.
contract Permit2 is Permit3 {
    constructor() Permit3(address(0), new ISignatureTransfer.ImportedNonceBitmap[](0), "") {}
}
