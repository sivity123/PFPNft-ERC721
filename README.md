# PFPNft-ERC721

A Foundry-based ERC721 profile picture NFT project with a Merkle-proof allowlist mint flow.

This repository shows how to:
- build a minimal ERC721 NFT in Solidity,
- generate Merkle inputs and outputs offchain,
- deploy the contract with a generated root hash,
- mint using the proof for an allowlisted address,
- test the same flow on Anvil or Sepolia.

## Overview

This project uses a Merkle tree based allowlist instead of storing every approved address onchain.

The flow is:

1. prepare a set of allowlisted addresses,
2. generate the Merkle input,
3. generate the Merkle root and proofs,
4. deploy the NFT contract with the root,
5. mint using the proof for the selected address.

Minting succeeds only when the address, proof, and root all come from the same generated tree.

## Project structure

```bash
.
├── broadcast/   # Foundry broadcast artifacts
├── lib/         # Dependencies
├── script/      # Deployment, interaction, and Merkle scripts
├── src/         # Smart contracts
├── test/        # Foundry tests
├── foundry.toml
└── README.md
```

## Requirements

Install the following first:

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git
- Sepolia ETH if you want to test on Sepolia

Verify installation:

```bash
forge --version
cast --version
anvil --version
```

## Getting started

This section is for developers who want to try the protocol with **their own set of accounts** instead of the default sample values.

### Step 1: Clone, install, and compile

```bash
git clone https://github.com/sivity123/PFPNft-ERC721.git
cd PFPNft-ERC721
forge install
forge build
```

If compilation fails, fix that first before moving to Merkle generation.

### Step 2: Choose your network

You can use:

- **Anvil/local** for quick local testing with local accounts.
- **Sepolia** for testing with real testnet wallets.

Important:
- for **Anvil**, generate inputs using Anvil addresses,
- for **Sepolia**, generate inputs using Sepolia addresses.

Do not generate proofs for one network and try to mint from another wallet set.

### Step 3: Use the correct input source

This project may contain two different input-generation flows.

Use:
- the local/Anvil-oriented input source for local testing,
- the real wallet input source for Sepolia testing.

For Sepolia, use `script/GenerateInput.s.sol` and replace the whitelist addresses with your own set of addresses.

### Step 4: Replace the whitelist addresses

Open the input-generation file and replace the default addresses with your own.

Example:

```solidity
address[] memory whitelist = new address[](2);
whitelist = 0x<replace-with-first-wallet>;
whitelist = 0x<replace-with-second-wallet>;[1]
```

- For **Anvil**, use Anvil accounts.
- For **Sepolia**, use the exact addresses that should be allowlisted.

### Step 5: Generate the raw input

Run:

```bash
forge script script/GenerateInput.s.sol:GenerateInput
```

This creates the raw Merkle input file.

For the standard local flow, check:

```bash
script/target/input.json
```

For your Sepolia flow, check:

```bash
script/targetSepolia/sepoliaInput.json
```

### Step 6: Generate the Merkle root and proofs

Run:

```bash
forge script script/MakeMerkle.s.sol:MakeMerkle
```

For the standard local flow, inspect:

```bash
script/target/output.json
```

For your Sepolia flow, inspect:

```bash
script/targetSepolia/sepoliaOutput.json
```

That output file contains:
- the generated `root`,
- the proofs for the addresses in the input list.

### Step 7: Copy the generated values

From the generated output file, copy:

- the **root hash**,
- the **proof** for the exact address you want to use.

Think of it like this:

- `input.json` / `sepoliaInput.json` = source addresses,
- `output.json` / `sepoliaOutput.json` = usable Merkle values.

### Step 8: Replace the root hash

Paste the generated root into the file or script that uses the Merkle root.

Example:

```solidity
bytes32 merkleRoot = 0x<replace-this-with-your-generated-root-hash>;
```

If you regenerate the tree later, you must update the root again.

### Step 9: Replace the proof

Paste the generated proof for the selected address into the test or interaction script.

Example:

```solidity
bytes32[] memory proof = new bytes32[](2);
proof = 0x<replace-this-with-your-proof-node-1>;
proof = 0x<replace-this-with-your-proof-node-2>;[1]
```

If your proof has more than two nodes, expand the array and include all nodes in the same order as the output file.

### Step 10: Keep these three values aligned

These must all come from the same generation run:

- the allowlisted address,
- the copied proof,
- the root hash used in deployment/config.

If one of them comes from a different run, verification will fail.

## Anvil flow

```bash
anvil
forge script script/GenerateInput.s.sol:GenerateInput
forge script script/MakeMerkle.s.sol:MakeMerkle
forge test
```

After generating the output:
- copy the root into your deploy/config file,
- copy the proof into the test or interaction script,
- test with the same allowlisted Anvil address.

## Sepolia flow

Add these to your `.env` file:

```bash
SEPOLIA_RPC_URL=<your-sepolia-rpc-url>
PRIVATE_KEY=<your-private-key>
ETHERSCAN_API_KEY=<your-etherscan-api-key>
```

Then load them:

```bash
source .env
```

Generate the Merkle data:

```bash
forge script script/GenerateInput.s.sol:GenerateInput
forge script script/MakeMerkle.s.sol:MakeMerkle
```

Then inspect:

```bash
script/targetSepolia/sepoliaOutput.json
```

Copy:
- the root into the deploy flow,
- the proof into the interaction script,
- and use the intended allowlisted Sepolia address consistently.

## Deployment

Deploy with the generated root hash:

```bash
forge script script/DeployPFPNft.s.sol:DeployPFPNft --sig "run(bytes32)" <root_hash> --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

The `<root_hash>` should come from:

```bash
script/targetSepolia/sepoliaOutput.json
```

## Interaction

Use the interaction script with the generated proof:

```bash
forge script script/Interactions.s.sol:Interactions --sig "run(uint256,address,bytes32,bytes32)" <payable_amount> <to> <proof_0> <proof_1> --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

Arguments:
- `payable_amount` = ETH sent with the mint transaction,
- `to` = allowlisted address that receives the NFT,
- `proof_0` = first proof node,
- `proof_1` = second proof node.

If your proof contains more nodes, update the script interface accordingly.

## Testing

Run local tests:

```bash
forge test -vvvv
```

Run Sepolia fork tests:

```bash
forge test --fork-url $SEPOLIA_URL -vvvv
```
