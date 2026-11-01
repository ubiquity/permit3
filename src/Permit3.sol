// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Permit2} from "./Permit2.sol";
import {EIP712} from "./EIP712.sol";
import {IEIP712} from "./interfaces/IEIP712.sol";
import {IPermit3} from "./interfaces/IPermit3.sol";

/// @notice Permit2-compatible transfers with batch nonce migration and version metadata.
/// @dev The administrator is trusted to invalidate unordered nonces for any token owner.
contract Permit3 is Permit2, IPermit3 {
    /// @inheritdoc IPermit3
    address public immutable override owner;

    /// @inheritdoc IPermit3
    string public override version;

    bytes32 private immutable _PERMIT3_DOMAIN_SEPARATOR;
    uint256 private immutable _PERMIT3_CHAIN_ID;

    /// @param owner_ Administrator, supplied explicitly to support deployment through factories.
    /// @param initialVersion Informational version or status message.
    /// @param initialNonces Previously used unordered nonce bitmap words to merge at deployment.
    constructor(address owner_, string memory initialVersion, NonceImport[] memory initialNonces) {
        if (owner_ == address(0)) revert InvalidOwner();
        owner = owner_;
        version = initialVersion;
        emit VersionUpdated(initialVersion);
        _PERMIT3_CHAIN_ID = block.chainid;
        _PERMIT3_DOMAIN_SEPARATOR = _buildPermit3DomainSeparator();
        _importNonces(initialNonces);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    /// @notice Returns the Permit3 signing domain, independently of version metadata.
    function DOMAIN_SEPARATOR() public view override(EIP712, IEIP712) returns (bytes32) {
        return block.chainid == _PERMIT3_CHAIN_ID ? _PERMIT3_DOMAIN_SEPARATOR : _buildPermit3DomainSeparator();
    }

    /// @inheritdoc IPermit3
    function importNonces(NonceImport[] calldata nonces) external override onlyOwner {
        _importNonces(nonces);
    }

    /// @inheritdoc IPermit3
    function getNonceBitmaps(NoncePosition[] calldata positions)
        external
        view
        override
        returns (uint256[] memory bitmaps)
    {
        bitmaps = new uint256[](positions.length);
        for (uint256 i = 0; i < positions.length; ++i) {
            NoncePosition calldata position = positions[i];
            bitmaps[i] = nonceBitmap[position.owner][position.wordPos];
        }
    }

    /// @inheritdoc IPermit3
    function setVersion(string calldata newVersion) external override onlyOwner {
        version = newVersion;
        emit VersionUpdated(newVersion);
    }

    function _importNonces(NonceImport[] memory nonces) private {
        for (uint256 i = 0; i < nonces.length; ++i) {
            NonceImport memory imported = nonces[i];
            nonceBitmap[imported.owner][imported.wordPos] |= imported.mask;
            emit UnorderedNonceInvalidation(imported.owner, imported.wordPos, imported.mask);
        }
    }

    function _buildPermit3DomainSeparator() private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                keccak256("Permit3"),
                block.chainid,
                address(this)
            )
        );
    }
}
