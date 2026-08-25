// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit3} from "../src/Permit3.sol";
import {InvalidNonce} from "../src/PermitErrors.sol";

contract Permit3Harness is Permit3 {
    constructor(
        Permit3.NonceBitmapImport[] memory initialNonceBitmaps,
        string memory initialVersion,
        string memory initialVersionNote,
        address initialOwner
    ) Permit3(initialNonceBitmaps, initialVersion, initialVersionNote, initialOwner) {}

    function useNonce(address from, uint256 nonce) external {
        _useUnorderedNonce(from, nonce);
    }
}

contract Permit3Test is Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event NonceBitmapImported(
        address indexed owner, uint256 indexed wordPos, uint256 importedBitmap, uint256 resultingBitmap
    );
    event VersionUpdated(string version, string note);

    address private constant ADMIN = address(0xA11CE);
    address private constant NEXT_ADMIN = address(0xB0B);
    address private constant TOKEN_OWNER = address(0xCAFE);

    bytes32 private constant EIP712_TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    function testConstructorImportsNonceBitmapsAndSetsVersion() public {
        Permit3.NonceBitmapImport[] memory imports = _imports(
            TOKEN_OWNER,
            7,
            (uint256(1) << 4) | (uint256(1) << 100),
            address(0xF00D),
            1,
            uint256(1) << 255
        );

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(0), ADMIN);
        vm.expectEmit(true, true, false, true);
        emit NonceBitmapImported(TOKEN_OWNER, 7, imports[0].bitmap, imports[0].bitmap);
        vm.expectEmit(true, true, false, true);
        emit NonceBitmapImported(address(0xF00D), 1, imports[1].bitmap, imports[1].bitmap);
        vm.expectEmit(false, false, false, true);
        emit VersionUpdated("3.0.0", "imported mainnet and gnosis nonce bitmaps");

        Permit3 permit3 = new Permit3(imports, "3.0.0", "imported mainnet and gnosis nonce bitmaps", ADMIN);

        assertEq(permit3.owner(), ADMIN);
        assertEq(permit3.version(), "3.0.0");
        assertEq(permit3.versionNote(), "imported mainnet and gnosis nonce bitmaps");
        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 7), imports[0].bitmap);
        assertEq(permit3.nonceBitmap(address(0xF00D), 1), imports[1].bitmap);
    }

    function testConstructorUsesPermit3DomainSeparator() public {
        Permit3 permit3 = new Permit3(_emptyImports(), "3.0.0", "", ADMIN);

        bytes32 expectedDomainSeparator =
            keccak256(abi.encode(EIP712_TYPE_HASH, keccak256("Permit3"), block.chainid, address(permit3)));

        assertEq(permit3.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function testOwnerCanImportNonceBitmapsAfterDeployment() public {
        Permit3 permit3 = new Permit3(_emptyImports(), "3.0.0", "", ADMIN);

        Permit3.NonceBitmapImport[] memory firstImport =
            _singleImport(TOKEN_OWNER, 0, (uint256(1) << 1) | (uint256(1) << 42));

        vm.prank(ADMIN);
        permit3.importNonceBitmaps(firstImport);

        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 0), firstImport[0].bitmap);

        Permit3.NonceBitmapImport[] memory secondImport =
            _singleImport(TOKEN_OWNER, 0, (uint256(1) << 42) | (uint256(1) << 200));
        uint256 expected = firstImport[0].bitmap | secondImport[0].bitmap;

        vm.expectEmit(true, true, false, true);
        emit NonceBitmapImported(TOKEN_OWNER, 0, secondImport[0].bitmap, expected);

        vm.prank(ADMIN);
        permit3.importNonceBitmaps(secondImport);

        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 0), expected);
    }

    function testBatchReadsNonceBitmaps() public {
        Permit3.NonceBitmapImport[] memory imports =
            _imports(TOKEN_OWNER, 0, uint256(1) << 1, TOKEN_OWNER, 9, uint256(1) << 250);
        Permit3 permit3 = new Permit3(imports, "3.0.0", "", ADMIN);
        uint256[] memory wordPositions = new uint256[](3);

        wordPositions[0] = 9;
        wordPositions[1] = 0;
        wordPositions[2] = 1;

        uint256[] memory bitmaps = permit3.nonceBitmaps(TOKEN_OWNER, wordPositions);

        assertEq(bitmaps.length, 3);
        assertEq(bitmaps[0], uint256(1) << 250);
        assertEq(bitmaps[1], uint256(1) << 1);
        assertEq(bitmaps[2], 0);
    }

    function testImportedNonceCannotBeUsed() public {
        Permit3Harness permit3 =
            new Permit3Harness(_singleImport(TOKEN_OWNER, 0, uint256(1) << 3), "3.0.0", "", ADMIN);

        vm.expectRevert(InvalidNonce.selector);
        permit3.useNonce(TOKEN_OWNER, 3);

        permit3.useNonce(TOKEN_OWNER, 4);

        assertEq(permit3.nonceBitmap(TOKEN_OWNER, 0), (uint256(1) << 3) | (uint256(1) << 4));
    }

    function testOnlyOwnerCanImportNonceBitmaps() public {
        Permit3 permit3 = new Permit3(_emptyImports(), "3.0.0", "", ADMIN);

        vm.expectRevert(Permit3.Unauthorized.selector);
        permit3.importNonceBitmaps(_singleImport(TOKEN_OWNER, 0, 1));
    }

    function testOnlyOwnerCanSetVersion() public {
        Permit3 permit3 = new Permit3(_emptyImports(), "3.0.0", "", ADMIN);

        vm.expectRevert(Permit3.Unauthorized.selector);
        permit3.setVersion("3.0.1", "deprecated on mainnet");

        vm.prank(ADMIN);
        vm.expectEmit(false, false, false, true);
        emit VersionUpdated("3.0.1", "deprecated on mainnet");
        permit3.setVersion("3.0.1", "deprecated on mainnet");

        assertEq(permit3.version(), "3.0.1");
        assertEq(permit3.versionNote(), "deprecated on mainnet");
    }

    function testTransferOwnership() public {
        Permit3 permit3 = new Permit3(_emptyImports(), "3.0.0", "", ADMIN);

        vm.expectRevert(Permit3.Unauthorized.selector);
        permit3.transferOwnership(NEXT_ADMIN);

        vm.prank(ADMIN);
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(ADMIN, NEXT_ADMIN);
        permit3.transferOwnership(NEXT_ADMIN);

        assertEq(permit3.owner(), NEXT_ADMIN);

        vm.prank(NEXT_ADMIN);
        permit3.setVersion("3.0.1", "new owner can update version");

        assertEq(permit3.versionNote(), "new owner can update version");
    }

    function testZeroOwnerReverts() public {
        vm.expectRevert(Permit3.ZeroOwner.selector);
        new Permit3(_emptyImports(), "3.0.0", "", address(0));
    }

    function _emptyImports() private pure returns (Permit3.NonceBitmapImport[] memory imports) {
        imports = new Permit3.NonceBitmapImport[](0);
    }

    function _singleImport(address importOwner, uint256 wordPos, uint256 bitmap)
        private
        pure
        returns (Permit3.NonceBitmapImport[] memory imports)
    {
        imports = new Permit3.NonceBitmapImport[](1);
        imports[0] = Permit3.NonceBitmapImport({owner: importOwner, wordPos: wordPos, bitmap: bitmap});
    }

    function _imports(
        address firstOwner,
        uint256 firstWordPos,
        uint256 firstBitmap,
        address secondOwner,
        uint256 secondWordPos,
        uint256 secondBitmap
    ) private pure returns (Permit3.NonceBitmapImport[] memory imports) {
        imports = new Permit3.NonceBitmapImport[](2);
        imports[0] = Permit3.NonceBitmapImport({owner: firstOwner, wordPos: firstWordPos, bitmap: firstBitmap});
        imports[1] = Permit3.NonceBitmapImport({owner: secondOwner, wordPos: secondWordPos, bitmap: secondBitmap});
    }
}
