// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeERC20, IERC20, IERC20Permit} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {Permit3} from "../src/Permit3.sol";
import {InvalidNonce} from "../src/PermitErrors.sol";

contract MockPermit3 is Permit3 {
    constructor(Permit3.NonceBitmapUpdate[] memory nonceImports) Permit3(nonceImports) {}

    function useUnorderedNonce(address from, uint256 nonce) public {
        _useUnorderedNonce(from, nonce);
    }
}

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

    function testImportUnorderedNonces() public {
        Permit3 permit3 = new Permit3(new Permit3.NonceBitmapUpdate[](0));
        Permit3.NonceBitmapUpdate[] memory updates = new Permit3.NonceBitmapUpdate[](2);
        updates[0] = Permit3.NonceBitmapUpdate({owner: address(0xbeef), word: 0, mask: 0x03});
        updates[1] = Permit3.NonceBitmapUpdate({owner: address(0xbeef), word: 1, mask: 0x10});

        permit3.importUnorderedNonces(updates);

        assertEq(permit3.nonceBitmap(address(0xbeef), 0), 0x03);
        assertEq(permit3.nonceBitmap(address(0xbeef), 1), 0x10);
    }

    function testImportUnorderedNoncesOrsExistingBitmap() public {
        Permit3 permit3 = new Permit3(new Permit3.NonceBitmapUpdate[](0));
        Permit3.NonceBitmapUpdate[] memory updates = new Permit3.NonceBitmapUpdate[](1);
        updates[0] = Permit3.NonceBitmapUpdate({owner: address(0xbeef), word: 0, mask: 0x01});
        permit3.importUnorderedNonces(updates);

        updates[0] = Permit3.NonceBitmapUpdate({owner: address(0xbeef), word: 0, mask: 0x04});
        permit3.importUnorderedNonces(updates);

        assertEq(permit3.nonceBitmap(address(0xbeef), 0), 0x05);
    }

    function testImportUnorderedNoncesUnauthorized() public {
        Permit3 permit3 = new Permit3(new Permit3.NonceBitmapUpdate[](0));
        Permit3.NonceBitmapUpdate[] memory updates = new Permit3.NonceBitmapUpdate[](1);
        updates[0] = Permit3.NonceBitmapUpdate({owner: address(0xbeef), word: 0, mask: 0x01});

        vm.prank(address(0xbad));
        vm.expectRevert(Permit3.UnauthorizedNonceImporter.selector);
        permit3.importUnorderedNonces(updates);
    }

    function testImportedNonceCannotBeUsed() public {
        MockPermit3 permit3 = new MockPermit3(new Permit3.NonceBitmapUpdate[](0));
        Permit3.NonceBitmapUpdate[] memory updates = new Permit3.NonceBitmapUpdate[](1);
        updates[0] = Permit3.NonceBitmapUpdate({owner: address(this), word: 0, mask: 1 << 5});
        permit3.importUnorderedNonces(updates);

        vm.expectRevert(InvalidNonce.selector);
        permit3.useUnorderedNonce(address(this), 5);
    }

    function testPermit3ConstructorImportsNonces() public {
        Permit3.NonceBitmapUpdate[] memory updates = new Permit3.NonceBitmapUpdate[](1);
        updates[0] = Permit3.NonceBitmapUpdate({owner: address(0xbeef), word: 2, mask: 0x40});

        Permit3 permit3 = new Permit3(updates);

        assertEq(permit3.nonceBitmap(address(0xbeef), 2), 0x40);
        assertEq(permit3.nonceImporter(), address(this));
    }
}
