// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";
import {SignatureTransfer} from "../src/SignatureTransfer.sol";

contract Permit3Test is Test {
    Permit3 permit3;
    address owner = address(0xABCD);
    address user = address(0xBEEF);

    function setUp() public {
        SignatureTransfer.NonceBitmapImport[] memory nonceImports = new SignatureTransfer.NonceBitmapImport[](2);
        nonceImports[0] = SignatureTransfer.NonceBitmapImport({owner: user, wordPos: 0, mask: 1 << 5});
        nonceImports[1] = SignatureTransfer.NonceBitmapImport({owner: user, wordPos: 1, mask: 1 << 3});

        vm.prank(owner);
        permit3 = new Permit3(nonceImports, "mainnet nonce import");
    }

    function testConstructorImportsNonceBitmapsAndVersionNote() public {
        assertEq(permit3.owner(), owner);
        assertEq(permit3.versionNote(), "mainnet nonce import");
        assertEq(permit3.nonceBitmap(user, 0), 1 << 5);
        assertEq(permit3.nonceBitmap(user, 1), 1 << 3);
    }

    function testBatchImportMergesNonceBitmaps() public {
        SignatureTransfer.NonceBitmapImport[] memory nonceImports = new SignatureTransfer.NonceBitmapImport[](2);
        nonceImports[0] = SignatureTransfer.NonceBitmapImport({owner: user, wordPos: 0, mask: 1 << 9});
        nonceImports[1] = SignatureTransfer.NonceBitmapImport({owner: address(0xCAFE), wordPos: 2, mask: 1 << 7});

        vm.prank(owner);
        permit3.importUnorderedNonces(nonceImports);

        assertEq(permit3.nonceBitmap(user, 0), (1 << 5) | (1 << 9));
        assertEq(permit3.nonceBitmap(address(0xCAFE), 2), 1 << 7);
    }

    function testOnlyOwnerCanImportNonceBitmaps() public {
        SignatureTransfer.NonceBitmapImport[] memory nonceImports = new SignatureTransfer.NonceBitmapImport[](1);
        nonceImports[0] = SignatureTransfer.NonceBitmapImport({owner: user, wordPos: 0, mask: 1});

        vm.expectRevert(Permit3.OnlyOwner.selector);
        permit3.importUnorderedNonces(nonceImports);
    }

    function testOnlyOwnerCanSetVersionNote() public {
        vm.prank(owner);
        permit3.setVersionNote("deprecated after migration");
        assertEq(permit3.versionNote(), "deprecated after migration");

        vm.expectRevert(Permit3.OnlyOwner.selector);
        permit3.setVersionNote("attacker note");
    }
}
