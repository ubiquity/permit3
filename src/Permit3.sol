// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AllowanceTransfer} from "./AllowanceTransfer.sol";
import {IPermit3} from "./interfaces/IPermit3.sol";
import {SignatureTransfer} from "./SignatureTransfer.sol";

/// @notice Permit3 handles signature transfers, allowance transfers, and migration nonce imports.
/// @dev Users must approve Permit3 before calling transfer functions.
contract Permit3 is IPermit3, SignatureTransfer, AllowanceTransfer {
    address public immutable owner;
    string public versionComment;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(
        address initialOwner,
        ImportedNonceBitmap[] memory usedNonceBitmaps,
        string memory initialVersionComment
    ) {
        owner = initialOwner == address(0) ? msg.sender : initialOwner;
        _importUnorderedNonceBitmaps(usedNonceBitmaps);

        if (bytes(initialVersionComment).length != 0) {
            versionComment = initialVersionComment;
            emit VersionCommentUpdated(initialVersionComment);
        }
    }

    /// @inheritdoc IPermit3
    function importUnorderedNonceBitmaps(ImportedNonceBitmap[] calldata usedNonceBitmaps) external onlyOwner {
        _importUnorderedNonceBitmaps(usedNonceBitmaps);
    }

    /// @inheritdoc IPermit3
    function setVersionComment(string calldata newVersionComment) external onlyOwner {
        versionComment = newVersionComment;
        emit VersionCommentUpdated(newVersionComment);
    }

    function _importUnorderedNonceBitmaps(ImportedNonceBitmap[] memory usedNonceBitmaps) internal {
        uint256 length = usedNonceBitmaps.length;
        for (uint256 i; i < length;) {
            ImportedNonceBitmap memory usedNonceBitmap = usedNonceBitmaps[i];
            nonceBitmap[usedNonceBitmap.owner][usedNonceBitmap.wordPos] |= usedNonceBitmap.bitmap;

            emit UnorderedNonceInvalidation(usedNonceBitmap.owner, usedNonceBitmap.wordPos, usedNonceBitmap.bitmap);

            unchecked {
                ++i;
            }
        }
    }
}
