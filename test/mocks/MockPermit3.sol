// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Permit3} from "../../src/Permit3.sol";
import {ISignatureTransfer} from "../../src/interfaces/ISignatureTransfer.sol";

contract MockPermit3 is Permit3 {
    constructor(ISignatureTransfer.NonceImport[] memory initialNonceImports, string memory initialVersion)
        Permit3(initialNonceImports, initialVersion)
    {}

    function useUnorderedNonce(address from, uint256 nonce) public {
        _useUnorderedNonce(from, nonce);
    }
}
