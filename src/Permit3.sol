// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Permit2} from "./Permit2.sol";

/// @notice Permit2-compatible deployment contract with optional constructor nonce bitmap imports.
contract Permit3 is Permit2 {
    /// @notice Thrown when a caller other than the nonce importer attempts to import nonce bitmaps.
    error UnauthorizedNonceImporter();

    /// @notice A nonce bitmap import entry.
    struct NonceBitmapUpdate {
        address owner;
        uint256 word;
        uint256 mask;
    }

    /// @notice The authorized address that can import nonce bitmaps for arbitrary owners.
    address public nonceImporter;

    constructor(NonceBitmapUpdate[] memory nonceImports) {
        nonceImporter = msg.sender;
        _importUnorderedNoncesMemory(nonceImports);
    }

    /// @notice Imports unordered nonce bitmaps for arbitrary owners.
    /// @dev Restricted to the nonce importer so arbitrary callers cannot invalidate other owners' permits.
    /// @param updates Array of owner, word, and bitmap mask updates to OR into nonceBitmap.
    function importUnorderedNonces(NonceBitmapUpdate[] calldata updates) external {
        if (msg.sender != nonceImporter) revert UnauthorizedNonceImporter();

        _importUnorderedNonces(updates);
    }

    function _importUnorderedNonces(NonceBitmapUpdate[] calldata updates) private {
        for (uint256 i = 0; i < updates.length; ++i) {
            _importUnorderedNonce(updates[i].owner, updates[i].word, updates[i].mask);
        }
    }

    function _importUnorderedNoncesMemory(NonceBitmapUpdate[] memory updates) private {
        for (uint256 i = 0; i < updates.length; ++i) {
            _importUnorderedNonce(updates[i].owner, updates[i].word, updates[i].mask);
        }
    }

    function _importUnorderedNonce(address owner, uint256 wordPos, uint256 mask) private {
        nonceBitmap[owner][wordPos] |= mask;

        emit UnorderedNonceInvalidation(owner, wordPos, mask);
    }
}
