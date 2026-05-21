// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {SignatureTransfer} from "./SignatureTransfer.sol";
import {AllowanceTransfer} from "./AllowanceTransfer.sol";
import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";

/// @notice Permit3 handles signature and allowance transfers while allowing migration of used Permit2 nonces.
/// @dev Users must approve Permit3 before calling any transfer functions.
contract Permit3 is SignatureTransfer, AllowanceTransfer, Ownable {
    string public version;

    event UnorderedNoncesImported(uint256 count);
    event VersionSet(string version);

    constructor(
        address[] memory owners,
        uint256[] memory wordPositions,
        uint256[] memory masks,
        string memory initialVersion
    ) {
        version = initialVersion;
        _importUnorderedNonces(owners, wordPositions, masks);
    }

    function importUnorderedNonces(
        address[] calldata owners,
        uint256[] calldata wordPositions,
        uint256[] calldata masks
    ) external onlyOwner {
        _importUnorderedNonces(owners, wordPositions, masks);
    }

    function setVersion(string calldata newVersion) external onlyOwner {
        version = newVersion;
        emit VersionSet(newVersion);
    }

    function _importUnorderedNonces(
        address[] memory owners,
        uint256[] memory wordPositions,
        uint256[] memory masks
    ) private {
        uint256 length = owners.length;
        if (length != wordPositions.length || length != masks.length) revert ISignatureTransfer.LengthMismatch();

        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                nonceBitmap[owners[i]][wordPositions[i]] |= masks[i];
            }
        }

        emit UnorderedNoncesImported(length);
    }
}
