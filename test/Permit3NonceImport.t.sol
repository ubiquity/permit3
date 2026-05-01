// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";

contract Permit3NonceImportTest is Test {
    address internal constant TOKEN_OWNER = address(0xA11CE);
    address internal constant DEPLOYER = address(0xD3A10);

    function testConstructorImportsInitialNonceBitmapsAndVersion() public {
        Permit3.NonceImport[] memory imports = new Permit3.NonceImport[](2);
        imports[0] = Permit3.NonceImport({owner: TOKEN_OWNER, wordPos: 0, mask: uint256(1) << 7});
        imports[1] = Permit3.NonceImport({owner: TOKEN_OWNER, wordPos: 3, mask: uint256(1) << 42});

        vm.prank(DEPLOYER);
        Permit3 permit3 = new Permit3(imports, "mainnet-nonces-imported-2026-05-01");

        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 0), uint256(1) << 7);
        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 3), uint256(1) << 42);
        assertEq(permit3.owner(), DEPLOYER);
        assertEq(permit3.version(), "mainnet-nonces-imported-2026-05-01");
    }

    function testOwnerCanBatchImportAdditionalNonceBitmaps() public {
        vm.prank(DEPLOYER);
        Permit3 permit3 = new Permit3(new Permit3.NonceImport[](0), "fresh-deploy");

        Permit3.NonceImport[] memory imports = new Permit3.NonceImport[](2);
        imports[0] = Permit3.NonceImport({owner: TOKEN_OWNER, wordPos: 1, mask: uint256(1) << 5});
        imports[1] = Permit3.NonceImport({owner: TOKEN_OWNER, wordPos: 1, mask: uint256(1) << 9});

        vm.prank(DEPLOYER);
        permit3.importUnorderedNonces(imports);

        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 1), (uint256(1) << 5) | (uint256(1) << 9));
    }

    function testNonOwnerCannotImportNonceBitmapsOrSetVersion() public {
        vm.prank(DEPLOYER);
        Permit3 permit3 = new Permit3(new Permit3.NonceImport[](0), "fresh-deploy");

        Permit3.NonceImport[] memory imports = new Permit3.NonceImport[](1);
        imports[0] = Permit3.NonceImport({owner: TOKEN_OWNER, wordPos: 0, mask: 1});

        vm.prank(address(0xBEEF));
        vm.expectRevert(Permit3.Unauthorized.selector);
        permit3.importUnorderedNonces(imports);

        vm.prank(address(0xBEEF));
        vm.expectRevert(Permit3.Unauthorized.selector);
        permit3.setVersion("deprecated");
    }

    function testOwnerCanSetVersion() public {
        vm.prank(DEPLOYER);
        Permit3 permit3 = new Permit3(new Permit3.NonceImport[](0), "fresh-deploy");

        vm.prank(DEPLOYER);
        permit3.setVersion("deprecated-after-import");

        assertEq(permit3.version(), "deprecated-after-import");
    }
}
