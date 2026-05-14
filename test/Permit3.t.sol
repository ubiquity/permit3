// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";
import {IPermit3} from "../src/interfaces/IPermit3.sol";
import {InvalidNonce} from "../src/PermitErrors.sol";

contract TestablePermit3 is Permit3 {
    constructor(
        address initialOwner,
        IPermit3.ImportedNonceBitmap[] memory usedNonceBitmaps,
        string memory initialVersionComment
    ) Permit3(initialOwner, usedNonceBitmaps, initialVersionComment) {}

    function useUnorderedNonce(address from, uint256 nonce) public {
        _useUnorderedNonce(from, nonce);
    }
}

contract Permit3Test is Test {
    event UnorderedNonceInvalidation(address indexed owner, uint256 word, uint256 mask);
    event VersionCommentUpdated(string versionComment);

    address private owner = address(0xA11CE);
    address private other = address(0xB0B);
    address private tokenOwner = address(0xCAFE);

    function testConstructorImportsUsedNonceBitmaps() public {
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](2);
        imports[0] = IPermit3.ImportedNonceBitmap({owner: tokenOwner, wordPos: 0, bitmap: 3});
        imports[1] = IPermit3.ImportedNonceBitmap({owner: tokenOwner, wordPos: 2, bitmap: 1 << 7});

        vm.expectEmit(true, false, false, true);
        emit UnorderedNonceInvalidation(tokenOwner, 0, 3);
        vm.expectEmit(true, false, false, true);
        emit UnorderedNonceInvalidation(tokenOwner, 2, 1 << 7);
        TestablePermit3 permit3 = new TestablePermit3(owner, imports, "");

        assertEq(permit3.nonceBitmap(tokenOwner, 0), 3);
        assertEq(permit3.nonceBitmap(tokenOwner, 2), 1 << 7);

        vm.expectRevert(InvalidNonce.selector);
        permit3.useUnorderedNonce(tokenOwner, 0);
        vm.expectRevert(InvalidNonce.selector);
        permit3.useUnorderedNonce(tokenOwner, 1);
        vm.expectRevert(InvalidNonce.selector);
        permit3.useUnorderedNonce(tokenOwner, 519);
    }

    function testOwnerCanImportMoreNonceBitmaps() public {
        TestablePermit3 permit3 = newPermit3("");
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](1);
        imports[0] = IPermit3.ImportedNonceBitmap({owner: tokenOwner, wordPos: 1, bitmap: 1 << 9});

        vm.expectEmit(true, false, false, true);
        emit UnorderedNonceInvalidation(tokenOwner, 1, 1 << 9);
        vm.prank(owner);
        permit3.importUnorderedNonceBitmaps(imports);

        assertEq(permit3.nonceBitmap(tokenOwner, 1), 1 << 9);
        vm.expectRevert(InvalidNonce.selector);
        permit3.useUnorderedNonce(tokenOwner, 265);
    }

    function testImportOrsExistingBitmap() public {
        TestablePermit3 permit3 = newPermit3("");
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](1);

        imports[0] = IPermit3.ImportedNonceBitmap({owner: tokenOwner, wordPos: 0, bitmap: 1});
        vm.prank(owner);
        permit3.importUnorderedNonceBitmaps(imports);

        imports[0] = IPermit3.ImportedNonceBitmap({owner: tokenOwner, wordPos: 0, bitmap: 4});
        vm.prank(owner);
        permit3.importUnorderedNonceBitmaps(imports);

        assertEq(permit3.nonceBitmap(tokenOwner, 0), 5);
    }

    function testOnlyOwnerCanImportOrSetVersionComment() public {
        TestablePermit3 permit3 = newPermit3("");
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](0);

        vm.prank(other);
        vm.expectRevert(IPermit3.NotOwner.selector);
        permit3.importUnorderedNonceBitmaps(imports);

        vm.prank(other);
        vm.expectRevert(IPermit3.NotOwner.selector);
        permit3.setVersionComment("deprecated");
    }

    function testVersionCommentCanBeSetDuringAndAfterDeployment() public {
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](0);

        vm.expectEmit(false, false, false, true);
        emit VersionCommentUpdated("initial migration");
        TestablePermit3 permit3 = new TestablePermit3(owner, imports, "initial migration");
        assertEq(permit3.versionComment(), "initial migration");

        vm.expectEmit(false, false, false, true);
        emit VersionCommentUpdated("deprecated on mainnet");
        vm.prank(owner);
        permit3.setVersionComment("deprecated on mainnet");
        assertEq(permit3.versionComment(), "deprecated on mainnet");
    }

    function testZeroInitialOwnerFallsBackToDeployer() public {
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](0);

        vm.prank(owner);
        TestablePermit3 permit3 = new TestablePermit3(address(0), imports, "");

        assertEq(permit3.owner(), owner);
    }

    function newPermit3(string memory initialVersionComment) private returns (TestablePermit3) {
        IPermit3.ImportedNonceBitmap[] memory imports = new IPermit3.ImportedNonceBitmap[](0);
        return new TestablePermit3(owner, imports, initialVersionComment);
    }
}
