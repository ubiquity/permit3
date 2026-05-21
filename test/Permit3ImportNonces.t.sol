// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";
import {ISignatureTransfer} from "../src/interfaces/ISignatureTransfer.sol";

contract Permit3ImportNoncesTest is Test {
    address internal constant ALICE = address(0xA11CE);
    address internal constant BOB = address(0xB0B);
    address internal constant NOT_OWNER = address(0xBAD);

    function testConstructorImportsNonceBitmapsAndVersion() public {
        (address[] memory owners, uint256[] memory wordPositions, uint256[] memory masks) = _nonceImports();

        Permit3 permit3 = new Permit3(owners, wordPositions, masks, "migrated from Permit2");

        assertEq(permit3.owner(), address(this));
        assertEq(permit3.version(), "migrated from Permit2");
        assertEq(permit3.nonceBitmap(ALICE, 0), 0x05);
        assertEq(permit3.nonceBitmap(ALICE, 1), 0x10);
        assertEq(permit3.nonceBitmap(BOB, 0), 0x80);
    }

    function testOwnerCanBatchImportFutureNonceBitmaps() public {
        Permit3 permit3 = _emptyPermit3();
        (address[] memory owners, uint256[] memory wordPositions, uint256[] memory masks) = _nonceImports();

        permit3.importUnorderedNonces(owners, wordPositions, masks);

        assertEq(permit3.nonceBitmap(ALICE, 0), 0x05);
        assertEq(permit3.nonceBitmap(ALICE, 1), 0x10);
        assertEq(permit3.nonceBitmap(BOB, 0), 0x80);

        masks[0] = 0x02;
        masks[1] = 0x20;
        masks[2] = 0x01;
        permit3.importUnorderedNonces(owners, wordPositions, masks);

        assertEq(permit3.nonceBitmap(ALICE, 0), 0x07);
        assertEq(permit3.nonceBitmap(ALICE, 1), 0x30);
        assertEq(permit3.nonceBitmap(BOB, 0), 0x81);
    }

    function testNonOwnerCannotBatchImportNonceBitmaps() public {
        Permit3 permit3 = _emptyPermit3();
        (address[] memory owners, uint256[] memory wordPositions, uint256[] memory masks) = _nonceImports();

        vm.prank(NOT_OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        permit3.importUnorderedNonces(owners, wordPositions, masks);
    }

    function testImportRejectsLengthMismatch() public {
        Permit3 permit3 = _emptyPermit3();
        address[] memory owners = new address[](1);
        uint256[] memory wordPositions = new uint256[](2);
        uint256[] memory masks = new uint256[](1);

        vm.expectRevert(ISignatureTransfer.LengthMismatch.selector);
        permit3.importUnorderedNonces(owners, wordPositions, masks);
    }

    function testOwnerCanSetVersion() public {
        Permit3 permit3 = _emptyPermit3();

        permit3.setVersion("deprecated: use latest deployment");

        assertEq(permit3.version(), "deprecated: use latest deployment");
    }

    function testNonOwnerCannotSetVersion() public {
        Permit3 permit3 = _emptyPermit3();

        vm.prank(NOT_OWNER);
        vm.expectRevert("Ownable: caller is not the owner");
        permit3.setVersion("bad");
    }

    function _emptyPermit3() private returns (Permit3) {
        address[] memory owners = new address[](0);
        uint256[] memory wordPositions = new uint256[](0);
        uint256[] memory masks = new uint256[](0);
        return new Permit3(owners, wordPositions, masks, "Permit3");
    }

    function _nonceImports()
        private
        pure
        returns (address[] memory owners, uint256[] memory wordPositions, uint256[] memory masks)
    {
        owners = new address[](3);
        wordPositions = new uint256[](3);
        masks = new uint256[](3);

        owners[0] = ALICE;
        wordPositions[0] = 0;
        masks[0] = 0x05;

        owners[1] = ALICE;
        wordPositions[1] = 1;
        masks[1] = 0x10;

        owners[2] = BOB;
        wordPositions[2] = 0;
        masks[2] = 0x80;
    }
}
