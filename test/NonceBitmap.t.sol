// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {Permit3} from "../src/Permit2.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {InvalidNonce} from "../src/PermitErrors.sol";

contract NonceBitmapTest is Test {
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

    function testConstructorImportsNonceBitmaps() public {
        ISignatureTransfer.NonceImport[] memory imports = new ISignatureTransfer.NonceImport[](2);
        imports[0] = ISignatureTransfer.NonceImport({owner: address(0xA11CE), word: 0, mask: 1 << 7});
        imports[1] = ISignatureTransfer.NonceImport({owner: address(0xB0B), word: 3, mask: 1 << 99});

        Permit3 permit3 = new Permit3(imports, "mainnet nonce import");

        assertEq(permit3.nonceImporter(), address(this));
        assertEq(permit3.versionNote(), "mainnet nonce import");
        assertEq(permit3.nonceBitmap(address(0xA11CE), 0), 1 << 7);
        assertEq(permit3.nonceBitmap(address(0xB0B), 3), 1 << 99);
    }

    function testImporterCanBatchImportNonceBitmaps() public {
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "");

        ISignatureTransfer.NonceImport[] memory imports = new ISignatureTransfer.NonceImport[](2);
        imports[0] = ISignatureTransfer.NonceImport({owner: address(0xA11CE), word: 1, mask: 1 << 4});
        imports[1] = ISignatureTransfer.NonceImport({owner: address(0xA11CE), word: 1, mask: 1 << 6});

        permit3.importUnorderedNonces(imports);

        assertEq(permit3.nonceBitmap(address(0xA11CE), 1), (1 << 4) | (1 << 6));
    }

    function testNonImporterCannotBatchImportNonceBitmaps() public {
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "");
        ISignatureTransfer.NonceImport[] memory imports = new ISignatureTransfer.NonceImport[](1);
        imports[0] = ISignatureTransfer.NonceImport({owner: address(0xA11CE), word: 1, mask: 1 << 4});

        vm.prank(address(0xB0B));
        vm.expectRevert(ISignatureTransfer.UnauthorizedNonceImporter.selector);
        permit3.importUnorderedNonces(imports);
    }

    function testTransferNonceImporterAndSetVersionNote() public {
        ISignatureTransfer.NonceImport[] memory emptyImports = new ISignatureTransfer.NonceImport[](0);
        Permit3 permit3 = new Permit3(emptyImports, "");

        permit3.transferNonceImporter(address(0xB0B));
        assertEq(permit3.nonceImporter(), address(0xB0B));

        vm.prank(address(0xB0B));
        permit3.setVersionNote("deprecated on gnosis");
        assertEq(permit3.versionNote(), "deprecated on gnosis");
    }
}
