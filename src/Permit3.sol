// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";
import {EIP712} from "./EIP712.sol";

/// @notice Permit3 handles signature-based transfers and allowance-based transfers with migration helpers.
/// @dev Users must approve Permit3 before calling any of the transfer functions.
contract Permit3 is SignatureTransfer, AllowanceTransfer {
    struct NonceBitmapImport {
        address owner;
        uint256 wordPos;
        uint256 bitmap;
    }

    error Unauthorized();
    error ZeroOwner();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event NonceBitmapImported(
        address indexed owner, uint256 indexed wordPos, uint256 importedBitmap, uint256 resultingBitmap
    );
    event VersionUpdated(string version, string note);

    address public owner;
    string public version;
    string public versionNote;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(
        NonceBitmapImport[] memory initialNonceBitmaps,
        string memory initialVersion,
        string memory initialVersionNote,
        address initialOwner
    ) EIP712("Permit3") {
        if (initialOwner == address(0)) revert ZeroOwner();

        owner = initialOwner;
        emit OwnershipTransferred(address(0), initialOwner);

        _importNonceBitmaps(initialNonceBitmaps);
        _setVersion(initialVersion, initialVersionNote);
    }

    /// @notice Imports used unordered nonce bitmaps for migrated owners.
    /// @dev Imported bits are ORed into storage so repeated imports are idempotent and cannot clear used nonces.
    function importNonceBitmaps(NonceBitmapImport[] calldata imports) external onlyOwner {
        _importNonceBitmaps(imports);
    }

    /// @notice Returns multiple unordered nonce bitmap words for one owner in a single call.
    function nonceBitmaps(address nonceOwner, uint256[] calldata wordPositions)
        external
        view
        returns (uint256[] memory bitmaps)
    {
        uint256 length = wordPositions.length;
        bitmaps = new uint256[](length);

        for (uint256 i = 0; i < length; ++i) {
            bitmaps[i] = nonceBitmap[nonceOwner][wordPositions[i]];
        }
    }

    /// @notice Updates the deployment version and optional operational note.
    function setVersion(string calldata newVersion, string calldata newVersionNote) external onlyOwner {
        _setVersion(newVersion, newVersionNote);
    }

    /// @notice Transfers migration/admin permissions to a new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroOwner();

        address previousOwner = owner;
        owner = newOwner;

        emit OwnershipTransferred(previousOwner, newOwner);
    }

    function _importNonceBitmaps(NonceBitmapImport[] memory imports) private {
        uint256 length = imports.length;

        for (uint256 i = 0; i < length; ++i) {
            NonceBitmapImport memory nonceImport = imports[i];
            uint256 resultingBitmap = nonceBitmap[nonceImport.owner][nonceImport.wordPos] | nonceImport.bitmap;

            nonceBitmap[nonceImport.owner][nonceImport.wordPos] = resultingBitmap;
            emit NonceBitmapImported(
                nonceImport.owner, nonceImport.wordPos, nonceImport.bitmap, resultingBitmap
            );
        }
    }

    function _setVersion(string memory newVersion, string memory newVersionNote) private {
        version = newVersion;
        versionNote = newVersionNote;

        emit VersionUpdated(newVersion, newVersionNote);
    }
}
