// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";

/// @notice Permit3 handles Permit2-compatible transfers and adds deployment-time and batch nonce imports.
/// @dev Users must approve Permit3 before calling any allowance transfer functions.
contract Permit3 is SignatureTransfer, AllowanceTransfer {
    address public immutable owner;
    string public versionNote;

    event NonceBitmapImported(address indexed owner, uint256 indexed wordPos, uint256 mask);
    event VersionNoteUpdated(string versionNote);

    error OnlyOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(NonceBitmapImport[] memory nonceImports, string memory initialVersionNote) {
        owner = msg.sender;
        _importNonceBitmaps(nonceImports);
        _setVersionNote(initialVersionNote);
    }

    /// @notice Imports unordered nonce bitmap words after deployment.
    /// @dev This is intended for cloning known-used nonce words from prior deployments.
    function importUnorderedNonces(NonceBitmapImport[] calldata nonceImports) external onlyOwner {
        uint256 length = nonceImports.length;
        for (uint256 i = 0; i < length; ++i) {
            NonceBitmapImport calldata nonceImport = nonceImports[i];
            nonceBitmap[nonceImport.owner][nonceImport.wordPos] |= nonceImport.mask;
            emit UnorderedNonceInvalidation(nonceImport.owner, nonceImport.wordPos, nonceImport.mask);
            emit NonceBitmapImported(nonceImport.owner, nonceImport.wordPos, nonceImport.mask);
        }
    }

    /// @notice Updates a human-readable version/deprecation note.
    function setVersionNote(string calldata newVersionNote) external onlyOwner {
        _setVersionNote(newVersionNote);
    }

    function _importNonceBitmaps(NonceBitmapImport[] memory nonceImports) private {
        _importUnorderedNonces(nonceImports);
        uint256 length = nonceImports.length;
        for (uint256 i = 0; i < length; ++i) {
            emit NonceBitmapImported(nonceImports[i].owner, nonceImports[i].wordPos, nonceImports[i].mask);
        }
    }

    function _setVersionNote(string memory newVersionNote) private {
        versionNote = newVersionNote;
        emit VersionNoteUpdated(newVersionNote);
    }
}
