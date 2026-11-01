// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";
import {IPermit3} from "../src/interfaces/IPermit3.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {InvalidNonce} from "../src/PermitErrors.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {PermitSignature} from "./utils/PermitSignature.sol";

contract Permit3Test is Test, PermitSignature {
    event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask);
    event VersionUpdated(string newVersion);

    Permit3 permit3;
    address constant ALICE = address(0xA11CE);
    address constant BOB = address(0xB0B);

    function setUp() public {
        permit3 = new Permit3(address(this), "3.0.0", new IPermit3.NonceImport[](0));
    }

    function testConstructorImportsMultipleOwnersAndDuplicateWords() public {
        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](5);
        nonces[0] = IPermit3.NonceImport(ALICE, 0, 1);
        nonces[1] = IPermit3.NonceImport(ALICE, 0, 2);
        nonces[2] = IPermit3.NonceImport(BOB, 7, type(uint256).max);
        nonces[3] = IPermit3.NonceImport(ALICE, type(uint248).max, uint256(1) << 255);
        nonces[4] = IPermit3.NonceImport(ALICE, 0, 0);
        Permit3 migrated = new Permit3(BOB, "migrated", nonces);

        assertEq(migrated.owner(), BOB);
        assertEq(migrated.version(), "migrated");
        assertEq(migrated.nonceBitmap(ALICE, 0), 3);
        assertEq(migrated.nonceBitmap(BOB, 7), type(uint256).max);
        assertEq(migrated.nonceBitmap(ALICE, type(uint248).max), uint256(1) << 255);
        assertEq(migrated.nonceBitmap(BOB, 0), 0);

        // The explicitly supplied owner, not the deploying contract or a CREATE2 factory, has authority.
        vm.expectRevert(IPermit3.Unauthorized.selector);
        migrated.importNonces(nonces);
        vm.prank(BOB);
        migrated.importNonces(nonces);
        assertEq(migrated.nonceBitmap(ALICE, 0), 3);
    }

    function testConstructorRejectsZeroOwner() public {
        vm.expectRevert(IPermit3.InvalidOwner.selector);
        new Permit3(address(0), "3.0.0", new IPermit3.NonceImport[](0));
    }

    function testImportEmitsInvalidationForEachWord() public {
        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](2);
        nonces[0] = IPermit3.NonceImport(ALICE, 1, 3);
        nonces[1] = IPermit3.NonceImport(BOB, 2, 4);
        vm.expectEmit(true, false, false, true, address(permit3));
        emit UnorderedNonceInvalidation(ALICE, 1, 3);
        vm.expectEmit(true, false, false, true, address(permit3));
        emit UnorderedNonceInvalidation(BOB, 2, 4);
        permit3.importNonces(nonces);
        assertEq(permit3.nonceBitmap(ALICE, 1), 3);
        assertEq(permit3.nonceBitmap(BOB, 2), 4);
    }

    function testFuzzImportPreservesUsedBits(address account, uint248 wordPos, uint256 existing, uint256 mask) public {
        vm.prank(account);
        permit3.invalidateUnorderedNonces(wordPos, existing);
        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](1);
        nonces[0] = IPermit3.NonceImport(account, wordPos, mask);
        permit3.importNonces(nonces);
        assertEq(permit3.nonceBitmap(account, wordPos), existing | mask);
        permit3.importNonces(nonces);
        assertEq(permit3.nonceBitmap(account, wordPos), existing | mask);
    }

    function testFuzzImportedNonceCannotBeSpent(address account, uint256 nonce) public {
        uint256 wordPos = nonce >> 8;
        uint256 mask = uint256(1) << uint8(nonce);
        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](1);
        nonces[0] = IPermit3.NonceImport(account, wordPos, mask);
        permit3.importNonces(nonces);

        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions(address(0), 0), nonce: nonce, deadline: type(uint256).max
        });
        ISignatureTransfer.SignatureTransferDetails memory details =
            ISignatureTransfer.SignatureTransferDetails(address(this), 0);
        vm.expectRevert(InvalidNonce.selector);
        permit3.permitTransferFrom(permit, details, account, bytes(""));
        assertEq(permit3.nonceBitmap(account, wordPos), mask);
    }

    function testUnauthorizedImportRevertsWithoutChangingBitmap() public {
        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](1);
        nonces[0] = IPermit3.NonceImport(ALICE, 0, 1);
        vm.expectRevert(IPermit3.Unauthorized.selector);
        vm.prank(BOB);
        permit3.importNonces(nonces);
        assertEq(permit3.nonceBitmap(ALICE, 0), 0);
    }

    function testBatchReadPreservesOrderAndDuplicates() public {
        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](2);
        nonces[0] = IPermit3.NonceImport(ALICE, 0, 3);
        nonces[1] = IPermit3.NonceImport(BOB, type(uint248).max, type(uint256).max);
        permit3.importNonces(nonces);
        IPermit3.NoncePosition[] memory positions = new IPermit3.NoncePosition[](4);
        positions[0] = IPermit3.NoncePosition(BOB, type(uint248).max);
        positions[1] = IPermit3.NoncePosition(ALICE, 0);
        positions[2] = IPermit3.NoncePosition(BOB, 0);
        positions[3] = IPermit3.NoncePosition(ALICE, 0);
        vm.prank(BOB);
        uint256[] memory bitmaps = permit3.getNonceBitmaps(positions);
        assertEq(bitmaps.length, 4);
        assertEq(bitmaps[0], type(uint256).max);
        assertEq(bitmaps[1], 3);
        assertEq(bitmaps[2], 0);
        assertEq(bitmaps[3], 3);
    }

    function testEmptyBatches() public {
        permit3.importNonces(new IPermit3.NonceImport[](0));
        uint256[] memory bitmaps = permit3.getNonceBitmaps(new IPermit3.NoncePosition[](0));
        assertEq(bitmaps.length, 0);
        assertEq(permit3.nonceBitmap(ALICE, 0), 0);
    }

    function testVersionUpdateEmitsEventAndPreservesDomain() public {
        bytes32 domain = permit3.DOMAIN_SEPARATOR();
        vm.expectEmit(false, false, false, true, address(permit3));
        emit VersionUpdated("deprecated: migrate to a new deployment");
        permit3.setVersion("deprecated: migrate to a new deployment");
        assertEq(permit3.version(), "deprecated: migrate to a new deployment");
        assertEq(permit3.DOMAIN_SEPARATOR(), domain);
        permit3.setVersion("");
        assertEq(permit3.version(), "");
    }

    function testUnauthorizedVersionUpdateReverts() public {
        vm.expectRevert(IPermit3.Unauthorized.selector);
        vm.prank(BOB);
        permit3.setVersion("deprecated");
        assertEq(permit3.version(), "3.0.0");
    }

    function testPermit3DomainSeparatorAndChainChange() public {
        bytes32 typeHash = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
        bytes32 nameHash = keccak256("Permit3");
        bytes32 domain = keccak256(abi.encode(typeHash, nameHash, block.chainid, address(permit3)));
        assertEq(permit3.DOMAIN_SEPARATOR(), domain);

        vm.chainId(block.chainid + 1);
        assertEq(
            permit3.DOMAIN_SEPARATOR(), keccak256(abi.encode(typeHash, nameHash, block.chainid, address(permit3)))
        );
        assertTrue(permit3.DOMAIN_SEPARATOR() != domain);
    }

    function testSignedTransferSurvivesMetadataUpdateAndImportPreservesSpentNonce() public {
        uint256 privateKey = 0x1234;
        address signer = vm.addr(privateKey);
        MockERC20 token = new MockERC20("Test", "TEST", 18);
        token.mint(signer, 10);
        vm.prank(signer);
        token.approve(address(permit3), type(uint256).max);
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions(address(token), 10),
            nonce: 255,
            deadline: type(uint256).max
        });
        ISignatureTransfer.SignatureTransferDetails memory details =
            ISignatureTransfer.SignatureTransferDetails(address(this), 10);
        bytes memory signature = getPermitTransferSignature(permit, privateKey, permit3.DOMAIN_SEPARATOR());
        permit3.setVersion("deprecated");
        permit3.permitTransferFrom(permit, details, signer, signature);
        assertEq(token.balanceOf(address(this)), 10);
        assertEq(token.balanceOf(signer), 0);

        IPermit3.NonceImport[] memory nonces = new IPermit3.NonceImport[](1);
        nonces[0] = IPermit3.NonceImport(signer, 0, 1);
        permit3.importNonces(nonces);
        assertEq(permit3.nonceBitmap(signer, 0), (uint256(1) << 255) | 1);
        vm.expectRevert(InvalidNonce.selector);
        permit3.permitTransferFrom(permit, details, signer, signature);
    }
}
