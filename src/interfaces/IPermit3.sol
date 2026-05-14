// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAllowanceTransfer} from "./IAllowanceTransfer.sol";
import {ISignatureTransfer} from "./ISignatureTransfer.sol";

/// @title Permit3
/// @notice Permit2-compatible interface with migration helpers for imported unordered nonces.
interface IPermit3 is ISignatureTransfer, IAllowanceTransfer {
    /// @notice Thrown when a caller is not the contract owner.
    error NotOwner();

    /// @notice Nonce bitmap data imported from an existing deployment.
    /// @param owner The token owner whose unordered nonce bitmap should be imported.
    /// @param wordPos The unordered nonce bitmap word position.
    /// @param bitmap The used nonce bitmap to OR into storage.
    struct ImportedNonceBitmap {
        address owner;
        uint256 wordPos;
        uint256 bitmap;
    }

    /// @notice Emits when the deployment/version comment changes.
    event VersionCommentUpdated(string versionComment);

    /// @notice Current owner allowed to import nonce bitmaps and update version metadata.
    function owner() external view returns (address);

    /// @notice Human-readable deployment/version/deprecation note.
    function versionComment() external view returns (string memory);

    /// @notice Imports used unordered nonce bitmap words after deployment.
    function importUnorderedNonceBitmaps(ImportedNonceBitmap[] calldata usedNonceBitmaps) external;

    /// @notice Updates the deployment/version/deprecation note.
    function setVersionComment(string calldata newVersionComment) external;
}
