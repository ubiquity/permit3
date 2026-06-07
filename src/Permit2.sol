// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";
import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";

/// @notice Permit3 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
/// @dev Users must approve Permit3 before calling any of the transfer functions.
contract Permit3 is SignatureTransfer, AllowanceTransfer {
    constructor(ISignatureTransfer.NonceImport[] memory importedNonces, string memory initialVersionNote)
        SignatureTransfer(importedNonces, initialVersionNote)
    {}
    // Permit3 unifies the two contracts so users have maximal flexibility with their approval.
}

/// @notice Compatibility wrapper for integrations still importing Permit2 from this package.
contract Permit2 is Permit3 {
    constructor() Permit3(new ISignatureTransfer.NonceImport[](0), "") {}
}
