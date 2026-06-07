// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "../src/Permit2.sol";
import {Permit3} from "../src/Permit3.sol";

// forge test --match-contract EIP712
contract EIP712Test is Test {
    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("Permit2");

    Permit2 permit2;

    function setUp() public {
        permit2 = new Permit2();
    }

    function testDomainSeparator() public {
        bytes32 expectedDomainSeparator = keccak256(abi.encode(TYPE_HASH, NAME_HASH, block.chainid, address(permit2)));

        assertEq(permit2.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function testDomainSeparatorAfterFork() public {
        bytes32 beginningSeparator = permit2.DOMAIN_SEPARATOR();
        uint256 newChainId = block.chainid + 1;
        vm.chainId(newChainId);
        assertTrue(permit2.DOMAIN_SEPARATOR() != beginningSeparator);

        bytes32 expectedDomainSeparator = keccak256(abi.encode(TYPE_HASH, NAME_HASH, newChainId, address(permit2)));
        assertEq(permit2.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    }

    function testDomainSeparatorPreservesPermit2Name() public {
        bytes32 permit2DomainSeparator =
            keccak256(abi.encode(TYPE_HASH, keccak256("Permit2"), block.chainid, address(permit2)));
        bytes32 permit3DomainSeparator =
            keccak256(abi.encode(TYPE_HASH, keccak256("Permit3"), block.chainid, address(permit2)));

        assertEq(permit2.DOMAIN_SEPARATOR(), permit2DomainSeparator);
        assertTrue(permit2.DOMAIN_SEPARATOR() != permit3DomainSeparator);
    }

    function testPermit3DomainSeparatorUsesPermit2Name() public {
        Permit3 permit3 = new Permit3(new Permit3.NonceBitmapUpdate[](0));
        bytes32 permit2DomainSeparator =
            keccak256(abi.encode(TYPE_HASH, keccak256("Permit2"), block.chainid, address(permit3)));
        bytes32 permit3DomainSeparator =
            keccak256(abi.encode(TYPE_HASH, keccak256("Permit3"), block.chainid, address(permit3)));

        assertEq(permit3.DOMAIN_SEPARATOR(), permit2DomainSeparator);
        assertTrue(permit3.DOMAIN_SEPARATOR() != permit3DomainSeparator);
    }
}
