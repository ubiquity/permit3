// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";

/// @notice Permit3 handles signature-based transfers in SignatureTransfer and allowance-based transfers in AllowanceTransfer.
/// @dev Users must approve Permit3 before calling any of the transfer functions.
contract Permit3 is SignatureTransfer, AllowanceTransfer {
    /// @notice Thrown when a caller is not the contract owner.
    error NotOwner();

    /// @notice Owner authorized to import nonce bitmaps and update the version comment.
    address public immutable owner;

    /// @notice Human-readable deployment version/deprecation comment set by the owner.
    string public versionComment;

    /// @notice Emitted when the owner updates the version comment.
    event VersionCommentUpdated(string versionComment);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Creates Permit3 and optionally imports already-used unordered nonce bitmaps.
    /// @param owner_ Owner authorized for future batch nonce imports and version comment updates.
    /// @param usedNonceBitmaps Already-used unordered nonce bitmap entries to import at deployment.
    /// @param initialVersionComment Initial human-readable version/deprecation comment.
    constructor(address owner_, ImportedNonceBitmap[] memory usedNonceBitmaps, string memory initialVersionComment) {
        owner = owner_ == address(0) ? msg.sender : owner_;
        versionComment = initialVersionComment;

        if (bytes(initialVersionComment).length != 0) emit VersionCommentUpdated(initialVersionComment);
        _importUnorderedNonceBitmaps(usedNonceBitmaps);
    }

    /// @inheritdoc SignatureTransfer
    function importUnorderedNonceBitmaps(ImportedNonceBitmap[] calldata usedNonceBitmaps) external onlyOwner {
        _importUnorderedNonceBitmaps(usedNonceBitmaps);
    }

    /// @notice Sets a human-readable deployment version/deprecation comment.
    /// @param newVersionComment New version/deprecation comment.
    function setVersionComment(string calldata newVersionComment) external onlyOwner {
        versionComment = newVersionComment;
        emit VersionCommentUpdated(newVersionComment);
    }
}
