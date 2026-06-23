// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Permit2} from "./Permit2.sol";
import {EIP712} from "./EIP712.sol";
import {IEIP712} from "./interfaces/IEIP712.sol";
import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";
import {UnauthorizedNonceImport} from "./PermitErrors.sol";

/// @notice Permit3 adds nonce migration helpers on top of Permit2.
contract Permit3 is Permit2 {
    bytes32 private constant _PERMIT3_HASHED_NAME = keccak256("Permit3");
    bytes32 private constant _PERMIT3_TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice Address allowed to import migrated unordered nonce bitmap words.
    address public immutable nonceMigrator;

    /// @notice Human-readable version or deprecation note for this deployment.
    string public version;

    /// @notice Emits when the version note is updated.
    event VersionSet(string version);

    /// @notice Deploys Permit3 and optionally imports used unordered nonce bitmap words.
    /// @param initialNonceImports Nonce bitmap words to mark as used during deployment
    /// @param initialVersion Initial human-readable version or deprecation note
    constructor(ISignatureTransfer.NonceImport[] memory initialNonceImports, string memory initialVersion) {
        nonceMigrator = msg.sender;
        version = initialVersion;

        if (bytes(initialVersion).length != 0) emit VersionSet(initialVersion);
        _importUnorderedNoncesOnDeployment(initialNonceImports);
    }

    /// @notice Updates the human-readable version or deprecation note.
    /// @param newVersion New version note
    function setVersion(string calldata newVersion) external {
        if (msg.sender != nonceMigrator) revert UnauthorizedNonceImport();

        version = newVersion;
        emit VersionSet(newVersion);
    }

    /// @notice Returns the Permit3 EIP-712 domain separator.
    function DOMAIN_SEPARATOR() public view override(EIP712, IEIP712) returns (bytes32) {
        return keccak256(abi.encode(_PERMIT3_TYPE_HASH, _PERMIT3_HASHED_NAME, block.chainid, address(this)));
    }

    function _canImportUnorderedNonces(address owner) internal view override returns (bool) {
        return owner == msg.sender || msg.sender == nonceMigrator;
    }
}
