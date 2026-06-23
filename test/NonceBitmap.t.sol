// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {MockPermit3} from "./mocks/MockPermit3.sol";
import {Permit3} from "../src/Permit3.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {InvalidNonce, UnauthorizedNonceImport} from "../src/PermitErrors.sol";

contract NonceBitmapTest is Test {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 private constant PERMIT3_NAME_HASH = keccak256("Permit3");

    MockPermit2 permit2;

    function setUp() public {
        permit2 = new MockPermit2();
    }

    function testLowNonces() public {
        permit2.useUnorderedNonce(address(this), 5);
        permit2.useUnorderedNonce(address(this), 0);
        permit2.useUnorderedNonce(address(this), 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 1);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 5);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 0);
        permit2.useUnorderedNonce(address(this), 4);
    }

    function testNonceWordBoundary() public {
        permit2.useUnorderedNonce(address(this), 255);
        permit2.useUnorderedNonce(address(this), 256);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 255);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 256);
    }

    function testHighNonces() public {
        permit2.useUnorderedNonce(address(this), 2 ** 240);
        permit2.useUnorderedNonce(address(this), 2 ** 240 + 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 2 ** 240);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 2 ** 240 + 1);
    }

    function testInvalidateFullWord() public {
        permit2.invalidateUnorderedNonces(0, 2 ** 256 - 1);

        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 0);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 1);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 254);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 255);
        permit2.useUnorderedNonce(address(this), 256);
    }

    function testInvalidateNonzeroWord() public {
        permit2.invalidateUnorderedNonces(1, 2 ** 256 - 1);

        permit2.useUnorderedNonce(address(this), 0);
        permit2.useUnorderedNonce(address(this), 254);
        permit2.useUnorderedNonce(address(this), 255);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 256);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), 511);
        permit2.useUnorderedNonce(address(this), 512);
    }

    function testUsingNonceTwiceFails(uint256 nonce) public {
        permit2.useUnorderedNonce(address(this), nonce);
        vm.expectRevert(InvalidNonce.selector);
        permit2.useUnorderedNonce(address(this), nonce);
    }

    function testUseTwoRandomNonces(uint256 first, uint256 second) public {
        permit2.useUnorderedNonce(address(this), first);
        if (first == second) {
            vm.expectRevert(InvalidNonce.selector);
            permit2.useUnorderedNonce(address(this), second);
        } else {
            permit2.useUnorderedNonce(address(this), second);
        }
    }

    function testInvalidateNoncesRandomly(uint248 wordPos, uint256 mask) public {
        permit2.invalidateUnorderedNonces(wordPos, mask);
        assertEq(mask, permit2.nonceBitmap(address(this), wordPos));
    }

    function testInvalidateTwoNoncesRandomly(uint248 wordPos, uint256 startBitmap, uint256 mask) public {
        permit2.invalidateUnorderedNonces(wordPos, startBitmap);
        assertEq(startBitmap, permit2.nonceBitmap(address(this), wordPos));

        // invalidating with the mask changes the original bitmap
        uint256 finalBitmap = startBitmap | mask;
        permit2.invalidateUnorderedNonces(wordPos, mask);
        uint256 savedBitmap = permit2.nonceBitmap(address(this), wordPos);
        assertEq(finalBitmap, savedBitmap);

        // invalidating with the same mask should do nothing
        permit2.invalidateUnorderedNonces(wordPos, mask);
        assertEq(savedBitmap, permit2.nonceBitmap(address(this), wordPos));
    }

    function testPermit3ImportsNoncesOnDeployment() public {
        address owner = address(0xB0B);
        ISignatureTransfer.NonceImport[] memory imports = new ISignatureTransfer.NonceImport[](2);
        imports[0] = ISignatureTransfer.NonceImport({owner: owner, wordPos: 0, mask: 3});
        imports[1] = ISignatureTransfer.NonceImport({owner: owner, wordPos: 2, mask: 1 << 7});

        MockPermit3 permit3 = new MockPermit3(imports, "mainnet migration");

        assertEq(permit3.nonceBitmap(owner, 0), 3);
        assertEq(permit3.nonceBitmap(owner, 2), 1 << 7);
        assertEq(permit3.version(), "mainnet migration");

        vm.expectRevert(InvalidNonce.selector);
        permit3.useUnorderedNonce(owner, 0);
        permit3.useUnorderedNonce(owner, 2);
    }

    function testPermit3MigratorCanBatchImportForAnyOwner() public {
        address ownerA = address(0xA11CE);
        address ownerB = address(0xB0B);
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "");

        ISignatureTransfer.NonceImport[] memory imports = new ISignatureTransfer.NonceImport[](3);
        imports[0] = ISignatureTransfer.NonceImport({owner: ownerA, wordPos: 0, mask: 1});
        imports[1] = ISignatureTransfer.NonceImport({owner: ownerA, wordPos: 1, mask: 4});
        imports[2] = ISignatureTransfer.NonceImport({owner: ownerB, wordPos: 0, mask: 2});
        permit3.importUnorderedNonces(imports);

        address[] memory owners = new address[](3);
        owners[0] = ownerA;
        owners[1] = ownerA;
        owners[2] = ownerB;

        uint256[] memory wordPositions = new uint256[](3);
        wordPositions[0] = 0;
        wordPositions[1] = 1;
        wordPositions[2] = 0;

        uint256[] memory bitmaps = permit3.nonceBitmapBatch(owners, wordPositions);
        assertEq(bitmaps[0], 1);
        assertEq(bitmaps[1], 4);
        assertEq(bitmaps[2], 2);
    }

    function testPermit3NonMigratorCanOnlyImportOwnNonces() public {
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "");

        ISignatureTransfer.NonceImport[] memory imports = new ISignatureTransfer.NonceImport[](1);
        imports[0] = ISignatureTransfer.NonceImport({owner: address(this), wordPos: 3, mask: 8});

        address user = address(0xA11CE);
        vm.prank(user);
        vm.expectRevert(UnauthorizedNonceImport.selector);
        permit3.importUnorderedNonces(imports);

        imports[0] = ISignatureTransfer.NonceImport({owner: user, wordPos: 3, mask: 8});
        vm.prank(user);
        permit3.importUnorderedNonces(imports);

        assertEq(permit3.nonceBitmap(user, 3), 8);
    }

    function testPermit3VersionSetterIsMigratorOnly() public {
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "initial");

        vm.prank(address(0xA11CE));
        vm.expectRevert(UnauthorizedNonceImport.selector);
        permit3.setVersion("deprecated");

        permit3.setVersion("deprecated");
        assertEq(permit3.version(), "deprecated");
    }

    function testPermit3DomainSeparatorUsesPermit3Name() public {
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "");

        bytes32 expectedDomainSeparator =
            keccak256(abi.encode(TYPE_HASH, PERMIT3_NAME_HASH, block.chainid, address(permit3)));
        assertEq(permit3.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function testNonceBitmapBatchLengthMismatch() public {
        address[] memory owners = new address[](1);
        uint256[] memory wordPositions = new uint256[](2);

        vm.expectRevert(ISignatureTransfer.LengthMismatch.selector);
        permit2.nonceBitmapBatch(owners, wordPositions);
    }
}
