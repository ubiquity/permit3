// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";
import {InvalidNonce} from "../src/PermitErrors.sol";

contract Permit3Test is Test {
    TestablePermit3 permit3;
    address owner = address(0xA11CE);
    address user = address(0xB0B);

    function setUp() public {
        ISignatureTransfer.ImportedNonceBitmap[] memory imports = new ISignatureTransfer.ImportedNonceBitmap[](2);
        imports[0] = ISignatureTransfer.ImportedNonceBitmap({owner: user, wordPos: 0, bitmap: 3});
        imports[1] = ISignatureTransfer.ImportedNonceBitmap({owner: user, wordPos: 2, bitmap: 1 << 7});

        permit3 = new TestablePermit3(owner, imports, "initial mainnet import");
    }

    function testConstructorImportsUsedNonceBitmaps() public {
        assertEq(permit3.nonceBitmap(user, 0), 3);
        assertEq(permit3.nonceBitmap(user, 2), 1 << 7);

        vm.expectRevert(InvalidNonce.selector);
        permit3.exposedUseUnorderedNonce(user, 0);
    }

    function testOwnerCanBatchImportLater() public {
        ISignatureTransfer.ImportedNonceBitmap[] memory imports = new ISignatureTransfer.ImportedNonceBitmap[](1);
        imports[0] = ISignatureTransfer.ImportedNonceBitmap({owner: user, wordPos: 0, bitmap: 1 << 5});

        vm.prank(owner);
        permit3.importUnorderedNonceBitmaps(imports);

        assertEq(permit3.nonceBitmap(user, 0), 3 | (1 << 5));
    }

    function testNonOwnerCannotBatchImport() public {
        ISignatureTransfer.ImportedNonceBitmap[] memory imports = new ISignatureTransfer.ImportedNonceBitmap[](1);
        imports[0] = ISignatureTransfer.ImportedNonceBitmap({owner: user, wordPos: 0, bitmap: 1 << 5});

        vm.expectRevert(Permit3.NotOwner.selector);
        permit3.importUnorderedNonceBitmaps(imports);
    }

    function testOwnerCanSetVersionComment() public {
        vm.prank(owner);
        permit3.setVersionComment("deprecated after gnosis sync");

        assertEq(permit3.versionComment(), "deprecated after gnosis sync");
    }
}

contract TestablePermit3 is Permit3 {
    constructor(
        address owner_,
        ISignatureTransfer.ImportedNonceBitmap[] memory usedNonceBitmaps,
        string memory initialVersionComment
    ) Permit3(owner_, usedNonceBitmaps, initialVersionComment) {}

    function exposedUseUnorderedNonce(address from, uint256 nonce) external {
        _useUnorderedNonce(from, nonce);
    }
}
