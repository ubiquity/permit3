// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";

/// @notice Permit3 extends Permit2-style signature and allowance transfers with deploy-time and owner-managed nonce imports.
/// @dev Nonce imports are intended to clone already-used nonce bitmaps from previous deployments so old signatures cannot be replayed.
contract Permit3 is SignatureTransfer, AllowanceTransfer {
    /// @notice Thrown when a caller tries to run an owner-only action.
    error Unauthorized();

    /// @notice A nonce bitmap import for one token owner and one unordered-nonce word.
    struct NonceImport {
        address owner;
        uint256 wordPos;
        uint256 mask;
    }

    /// @notice Owner allowed to import historic nonce bitmaps and annotate deployment version state.
    address public immutable owner;

    /// @notice Free-form deployment/version note, e.g. imported source chains or deprecation comments.
    string public version;

    /// @notice Emitted when imported nonce bits are merged into an owner's bitmap.
    event ImportedUnorderedNonceBitmap(address indexed owner, uint256 indexed wordPos, uint256 mask);

    /// @notice Emitted when the deployment/version note changes.
    event VersionUpdated(string version);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @notice Deploy Permit3 and optionally pre-load already-used unordered nonces.
    /// @param initialNonceImports Historic nonce bitmap masks to OR into storage at deployment.
    /// @param initialVersion Free-form version/deprecation/import note.
    constructor(NonceImport[] memory initialNonceImports, string memory initialVersion) {
        owner = msg.sender;
        version = initialVersion;
        _importUnorderedNonces(initialNonceImports);
        emit VersionUpdated(initialVersion);
    }

    /// @notice Import additional used unordered nonce bitmaps after deployment.
    /// @dev Restricted to the deployer/owner to avoid arbitrary third parties griefing token owners by burning nonces.
    /// @param imports Nonce bitmap masks to OR into storage.
    function importUnorderedNonces(NonceImport[] calldata imports) external onlyOwner {
        _importUnorderedNonces(imports);
    }

    /// @notice Update the free-form version/deprecation/import note.
    function setVersion(string calldata newVersion) external onlyOwner {
        version = newVersion;
        emit VersionUpdated(newVersion);
    }

    function _importUnorderedNonces(NonceImport[] memory imports) internal {
        for (uint256 i = 0; i < imports.length; ++i) {
            nonceBitmap[imports[i].owner][imports[i].wordPos] |= imports[i].mask;
            emit ImportedUnorderedNonceBitmap(imports[i].owner, imports[i].wordPos, imports[i].mask);
        }
    }
}
