// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IPermit2} from "./IPermit2.sol";

/// @notice Permit2-compatible transfers with owner-controlled nonce migration and version metadata.
interface IPermit3 is IPermit2 {
    error Unauthorized();
    error InvalidOwner();

    /// @notice Emitted when the informational version or deprecation message changes.
    event VersionUpdated(string newVersion);

    struct NonceImport {
        address owner;
        uint256 wordPos;
        uint256 mask;
    }

    struct NoncePosition {
        address owner;
        uint256 wordPos;
    }

    /// @notice The immutable administrator authorized to import nonces and update metadata.
    function owner() external view returns (address);

    /// @notice Informational metadata, independent of the EIP-712 signing domain.
    function version() external view returns (string memory);

    /// @notice Permanently marks the supplied nonce bits as used for their respective owners.
    /// @dev Only the administrator may call this. Masks are ORed, never replacing existing bits.
    /// Emits UnorderedNonceInvalidation for each imported word. Only unordered nonces are imported.
    function importNonces(NonceImport[] calldata nonces) external;

    /// @notice Reads known owner/word pairs in input order, including zero words and duplicates.
    /// @dev Mappings cannot enumerate their keys; callers must supply the positions to query.
    function getNonceBitmaps(NoncePosition[] calldata positions) external view returns (uint256[] memory bitmaps);

    /// @notice Sets a version or deprecation message without changing signed permit validity.
    /// @dev Only the administrator may call this.
    function setVersion(string calldata newVersion) external;
}
