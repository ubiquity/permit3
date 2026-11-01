# permit3

Permit3 extends Permit2 with batch unordered-nonce migration and administrator-controlled version metadata. The original Permit2 contracts and utilities remain available for legacy integrations.

## Nonce migration and metadata

Deploy `src/Permit3.sol` with `(owner, initialVersion, initialNonces)`. Supply the administrator explicitly (for example, a multisig), rather than relying on the deployer, which may be a CREATE2 factory. The owner is immutable and must not be the zero address.

Each `IPermit3.NonceImport` contains `(owner, wordPos, mask)`: the token owner, the bitmap word position, and the used bits read from the old deployment's `nonceBitmap(owner, wordPos)`. For an individual nonce, `wordPos = nonce >> 8` and `mask = 1 << (nonce & 255)`.

- Constructor imports and later `importNonces(NonceImport[])` calls OR masks into the current bitmap. Existing used bits are never cleared; duplicate imports and empty arrays are safe.
- Only the administrator can import nonces for other owners. This is a trusted role: it can invalidate any owner's unordered permits, but cannot make used nonces usable again. Token owners retain `invalidateUnorderedNonces` for their own nonces.
- Each imported word emits `UnorderedNonceInvalidation`. Large migrations can be split across transactions using `importNonces` to stay within the chain's gas limit.
- `getNonceBitmaps(NoncePosition[])` reads known `(owner, wordPos)` pairs in one call and returns words in the same order. Solidity mappings cannot enumerate their keys; there is no practical way to read every possible word (there are up to 2^248 positions per owner). Obtain the relevant owner/word pairs from migration data or indexed transaction history. On a legacy deployment, batch its existing `nonceBitmap` getter calls using JSON-RPC batching or a multicall.
- Only unordered signature-transfer nonces are imported. Token approvals and allowance-transfer state must be established separately for the new contract.

The administrator can call `setVersion(string)` to publish a version or deprecation comment, observable through `version()` and `VersionUpdated`. This is informational metadata, not an upgrade or pause switch, and does not invalidate existing signatures. Permit3 uses the EIP-712 domain name **Permit3** (the legacy contract uses **Permit2**); clients must sign for the new contract address and chain. The mutable version message is not part of that signing domain.

## Features

- **Signature Based Approvals**: Any ERC20 token, even those that do not support [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612), can now use permit style approvals. This allows applications to have a single transaction flow by sending a permit signature along with the transaction data when using `Permit2` integrated contracts.
- **Batched Token Approvals**: Set permissions on different tokens to different spenders with one signature.
- **Signature Based Token Transfers**: Owners can sign messages to transfer tokens directly to signed spenders, bypassing setting any allowance. This means that approvals aren't necessary for applications to receive tokens and that there will never be hanging approvals when using this method. The signature is valid only for the duration of the transaction in which it is spent.
- **Batched Token Transfers**: Transfer different tokens to different recipients with one signature.
- **Safe Arbitrary Data Verification**: Verify any extra data by passing through a witness hash and witness type. The type string must follow the [EIP-712](https://eips.ethereum.org/EIPS/eip-712) standard.
- **Signature Verification for Contracts**: All signature verification supports [EIP-1271](https://eips.ethereum.org/EIPS/eip-1271) so contracts can approve tokens and transfer tokens through signatures.
- **Non-monotonic Replay Protection**: Signature based transfers use unordered, non-monotonic nonces so that signed permits do not need to be transacted in any particular order.
- **Expiring Approvals**: Approvals can be time-bound, removing security concerns around hanging approvals on a wallet’s entire token balance. This also means that revoking approvals do not necessarily have to be a new transaction since an approval that expires will no longer be valid.
- **Batch Revoke Allowances**: Remove allowances on any number of tokens and spenders in one transaction.

## Architecture

Permit2 is the union of two contracts: [`AllowanceTransfer`](https://github.com/Uniswap/permit2/blob/main/src/AllowanceTransfer.sol) and [`SignatureTransfer`](https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol).

The `SignatureTransfer` contract handles all signature-based transfers, meaning that an allowance on the token is bypassed and permissions to the spender only last for the duration of the transaction that the one-time signature is spent.

The `AllowanceTransfer` contract handles setting allowances on tokens, giving permissions to spenders on a specified amount for a specified duration of time. Any transfers that then happen through the `AllowanceTransfer` contract will only succeed if the proper permissions have been set.

## Integrating with Permit3

Integrate through `src/interfaces/IPermit3.sol`. Before contracts can request users’ tokens through `Permit3`, users must approve the new `Permit3` address through each token contract. The inherited transfer APIs are documented on the Uniswap [documentation site](https://docs.uniswap.org/contracts/permit2/overview).

### Note on viaIR compilation
Permit3 and Permit2 use viaIR compilation, so importing and deploying them in integration tests requires viaIR compilation as well. For legacy Permit2-only tests, compilation can be avoided using the precompiled `DeployPermit2` utility below. It does not deploy Permit3; deploy Permit3 with its constructor when testing the migration APIs.
```
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";

contract MyTest is DeployPermit2 {
    address permit2;

    function setUp() public {
        permit2 = deployPermit2();
    }
}
```

## Bug Bounty

This repository is subject to the Uniswap Labs Bug Bounty program, per the terms defined [here](https://uniswap.org/bug-bounty).

## Contributing

You will need a copy of [Foundry](https://github.com/foundry-rs/foundry) installed before proceeding. See the [installation guide](https://github.com/foundry-rs/foundry#installation) for details.

### Setup

```sh
git clone https://github.com/Uniswap/permit2.git
cd permit2
forge install
```

### Lint

```sh
forge fmt [--check]
```

### Run Tests

```sh
# unit
forge test

# integration
source .env
FOUNDRY_PROFILE=integration forge test
```

### Update Gas Snapshots

```sh
forge snapshot
```

### Deploy

Deploy Permit3 with an explicit administrator, initial version message, and nonce-import array. Replace `[]` with `[(tokenOwner,wordPos,mask),...]` to seed used nonce words. Remove `--broadcast`, `--rpc-url`, `--private-key` and `--verify` options to test locally.

```sh
forge script script/DeployPermit3.s.sol:DeployPermit3 \
  --sig "run(address,string,(address,uint256,uint256)[])" <OWNER> "3.0.0" "[]" \
  --broadcast --rpc-url <RPC-URL> --private-key <PRIVATE_KEY> --verify
```

## Acknowledgments

Inspired by [merklejerk](https://github.com/merklejerk)'s [permit-everywhere](https://github.com/merklejerk/permit-everywhere) contracts which introduce permit based approvals for all tokens regardless of EIP2612 support.
