// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ISignatureTransfer} from "./interfaces/ISignatureTransfer.sol";
import {SignatureExpired, InvalidNonce, UnauthorizedNonceImport} from "./PermitErrors.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";
import {SignatureVerification} from "./libraries/SignatureVerification.sol";
import {PermitHash} from "./libraries/PermitHash.sol";
import {EIP712} from "./EIP712.sol";

contract SignatureTransfer is ISignatureTransfer, EIP712 {
    using SignatureVerification for bytes;
    using SafeTransferLib for ERC20;
    using PermitHash for PermitTransferFrom;
    using PermitHash for PermitBatchTransferFrom;

    /// @inheritdoc ISignatureTransfer
    mapping(address => mapping(uint256 => uint256)) public nonceBitmap;

    /// @inheritdoc ISignatureTransfer
    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        _permitTransferFrom(permit, transferDetails, owner, permit.hash(), signature);
    }

    /// @inheritdoc ISignatureTransfer
    function permitWitnessTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        _permitTransferFrom(
            permit, transferDetails, owner, permit.hashWithWitness(witness, witnessTypeString), signature
        );
    }

    /// @notice Transfers a token using a signed permit message.
    /// @param permit The permit data signed over by the owner
    /// @param dataHash The EIP-712 hash of permit data to include when checking signature
    /// @param owner The owner of the tokens to transfer
    /// @param transferDetails The spender's requested transfer details for the permitted token
    /// @param signature The signature to verify
    function _permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes32 dataHash,
        bytes calldata signature
    ) private {
        uint256 requestedAmount = transferDetails.requestedAmount;

        if (block.timestamp > permit.deadline) revert SignatureExpired(permit.deadline);
        if (requestedAmount > permit.permitted.amount) revert InvalidAmount(permit.permitted.amount);

        _useUnorderedNonce(owner, permit.nonce);

        signature.verify(_hashTypedData(dataHash), owner);

        ERC20(permit.permitted.token).safeTransferFrom(owner, transferDetails.to, requestedAmount);
    }

    /// @inheritdoc ISignatureTransfer
    function permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external {
        _permitTransferFrom(permit, transferDetails, owner, permit.hash(), signature);
    }

    /// @inheritdoc ISignatureTransfer
    function permitWitnessTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 witness,
        string calldata witnessTypeString,
        bytes calldata signature
    ) external {
        _permitTransferFrom(
            permit, transferDetails, owner, permit.hashWithWitness(witness, witnessTypeString), signature
        );
    }

    /// @notice Transfers tokens using a signed permit messages
    /// @param permit The permit data signed over by the owner
    /// @param dataHash The EIP-712 hash of permit data to include when checking signature
    /// @param owner The owner of the tokens to transfer
    /// @param signature The signature to verify
    function _permitTransferFrom(
        PermitBatchTransferFrom memory permit,
        SignatureTransferDetails[] calldata transferDetails,
        address owner,
        bytes32 dataHash,
        bytes calldata signature
    ) private {
        uint256 numPermitted = permit.permitted.length;

        if (block.timestamp > permit.deadline) revert SignatureExpired(permit.deadline);
        if (numPermitted != transferDetails.length) revert LengthMismatch();

        _useUnorderedNonce(owner, permit.nonce);
        signature.verify(_hashTypedData(dataHash), owner);

        unchecked {
            for (uint256 i = 0; i < numPermitted; ++i) {
                TokenPermissions memory permitted = permit.permitted[i];
                uint256 requestedAmount = transferDetails[i].requestedAmount;

                if (requestedAmount > permitted.amount) revert InvalidAmount(permitted.amount);

                if (requestedAmount != 0) {
                    // allow spender to specify which of the permitted tokens should be transferred
                    ERC20(permitted.token).safeTransferFrom(owner, transferDetails[i].to, requestedAmount);
                }
            }
        }
    }

    /// @inheritdoc ISignatureTransfer
    function invalidateUnorderedNonces(uint256 wordPos, uint256 mask) external {
        nonceBitmap[msg.sender][wordPos] |= mask;

        emit UnorderedNonceInvalidation(msg.sender, wordPos, mask);
    }

    /// @inheritdoc ISignatureTransfer
    function importUnorderedNonces(NonceImport[] calldata imports) external {
        uint256 length = imports.length;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                NonceImport calldata nonceImport = imports[i];
                _importUnorderedNonce(nonceImport.owner, nonceImport.wordPos, nonceImport.mask, true);
            }
        }
    }

    /// @notice Imports unordered nonce words during construction without msg.sender ownership checks.
    /// @param imports The owner, word position, and bitmap mask tuples to import
    function _importUnorderedNoncesOnDeployment(NonceImport[] memory imports) internal {
        uint256 length = imports.length;
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                NonceImport memory nonceImport = imports[i];
                _importUnorderedNonce(nonceImport.owner, nonceImport.wordPos, nonceImport.mask, false);
            }
        }
    }

    /// @notice Imports a single unordered nonce bitmap word.
    /// @param owner Owner whose nonce word is imported
    /// @param wordPos Word position to import
    /// @param mask Bitmap mask to mark as used
    /// @param requireAuthorization Whether the import must be authorized for msg.sender
    function _importUnorderedNonce(address owner, uint256 wordPos, uint256 mask, bool requireAuthorization) private {
        if (requireAuthorization && !_canImportUnorderedNonces(owner)) revert UnauthorizedNonceImport();

        nonceBitmap[owner][wordPos] |= mask;
        emit UnorderedNonceImport(owner, wordPos, mask);
    }

    /// @notice Returns whether msg.sender can import unordered nonce words for owner.
    /// @dev Permit2-compatible default requires users to import their own nonce words.
    function _canImportUnorderedNonces(address owner) internal view virtual returns (bool) {
        return owner == msg.sender;
    }

    /// @inheritdoc ISignatureTransfer
    function nonceBitmapBatch(address[] calldata owners, uint256[] calldata wordPositions)
        external
        view
        returns (uint256[] memory bitmaps)
    {
        uint256 length = owners.length;
        if (length != wordPositions.length) revert LengthMismatch();

        bitmaps = new uint256[](length);
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                bitmaps[i] = nonceBitmap[owners[i]][wordPositions[i]];
            }
        }
    }

    /// @notice Returns the index of the bitmap and the bit position within the bitmap. Used for unordered nonces
    /// @param nonce The nonce to get the associated word and bit positions
    /// @return wordPos The word position or index into the nonceBitmap
    /// @return bitPos The bit position
    /// @dev The first 248 bits of the nonce value is the index of the desired bitmap
    /// @dev The last 8 bits of the nonce value is the position of the bit in the bitmap
    function bitmapPositions(uint256 nonce) private pure returns (uint256 wordPos, uint256 bitPos) {
        wordPos = uint248(nonce >> 8);
        bitPos = uint8(nonce);
    }

    /// @notice Checks whether a nonce is taken and sets the bit at the bit position in the bitmap at the word position
    /// @param from The address to use the nonce at
    /// @param nonce The nonce to spend
    function _useUnorderedNonce(address from, uint256 nonce) internal {
        (uint256 wordPos, uint256 bitPos) = bitmapPositions(nonce);
        uint256 bit = 1 << bitPos;
        uint256 flipped = nonceBitmap[from][wordPos] ^= bit;

        if (flipped & bit == 0) revert InvalidNonce();
    }

    /// @inheritdoc ISignatureTransfer
    /// @notice Batch transfer: transfers tokens using multiple single-token permits and provided transfer details
    function batchPermitTransferFrom(
        PermitTransferFrom[] calldata permits,
        SignatureTransferDetails[] calldata transferDetails,
        address[] calldata owners,
        bytes[] calldata signatures
    ) external {
        uint256 length = permits.length;
        if (length != transferDetails.length || length != owners.length || length != signatures.length) revert LengthMismatch();
        for (uint256 i = 0; i < length; ++i) {
            _permitTransferFrom(
                permits[i],
                transferDetails[i],
                owners[i],
                permits[i].hash(),
                signatures[i]
            );
        }
    }
}
