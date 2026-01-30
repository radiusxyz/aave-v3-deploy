# Aave V3 Testing Guide

## Overview

### Helper Scripts (`utils/helpers/`)
Atomic, reusable components:

1. **`load_addresses.sh`** - Loads all contract addresses from deployments
2. **`load_abi.sh`** - Extracts ABIs for cast interactions
3. **`01_SUPPLY.sh`** - Supply tokens to Aave Pool
4. **`02_WITHDRAW.sh`** - Withdraw tokens from Aave Pool
5. **`03_BORROW.sh`** - Borrow tokens against collateral
6. **`04_REPAY.sh`** - Repay borrowed tokens
7. **`05_LIQUIDATE.sh`** - Liquidate unhealthy positions
8. **`06_QUERY.sh`** - Query user balances (wallet, aTokens, debt tokens)
9. **`07_APPROVE.sh`** - Approve token spending
10. **`08_MINT_TOKENS.sh`** - Mint testnet tokens
11. **`09_MANIPULATE_ORACLE.sh`** - Change oracle prices (for liquidation testing)

### Scenario Scripts (`utils/scripts/`)
End-to-end test flows:

1. **`00_SETUP_ACCOUNTS.sh`** - Funds 5 test accounts with 0.5 ETH each
2. **`01_SCENARIO_WETH_SUPPLY.sh`** - Account 0 supplies WETH
3. **`02_SCENARIO_USDT_SUPPLY_BORROW.sh`** - Account 1 supplies USDT, borrows WETH
4. **`03_SCENARIO_USDC_MAX_BORROW.sh`** - Account 2 supplies USDC, borrows max WETH (80% LTV)
5. **`04_SCENARIO_WBTC_SUPPLY_WITHDRAW.sh`** - Account 3 supplies and withdraws WBTC
6. **`05_SCENARIO_LIQUIDATION.sh`** - Account 4 liquidates Account 2's position

## How to Run

### Prerequisites

Install required tools:

```bash
# Install Foundry (for cast)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install jq (JSON processor)
brew install jq  # macOS
# or
sudo apt-get install jq  # Linux

# bc is usually pre-installed
```

### Setup Your Environment

Add these to your `.env` file:

```env
# Your existing variables
MARKET_NAME=Aave
ALCHEMY_KEY=...
MNEMONIC=...

# Add these for testing
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY}
DEPLOYER_PRIVATE_KEY=<your_deployer_private_key>
```

**IMPORTANT:** Replace `DEPLOYER_PRIVATE_KEY` with the actual private key of the deployer address (`0x67c1BD4630e1361A6F366bB2909920e29BE91547`).

### Step-by-Step Execution

#### Step 1: Fund Test Accounts

```bash
./utils/scripts/00_SETUP_ACCOUNTS.sh
```

This sends 0.5 ETH to each of the 5 test accounts.

#### Step 2: Configure Faucet

```bash
./utils/scripts/00_CONFIGURE_FAUCET.sh
```

Setup faucuet to be able to mint all tokens.

#### Step 3: Run Scenarios

Run each scenario in order:

```bash
# Scenario 1: Simple WETH supply
./utils/scripts/01_SCENARIO_WETH_SUPPLY.sh

# Scenario 2: USDT supply + WETH borrow
./utils/scripts/02_SCENARIO_USDT_SUPPLY_BORROW.sh

# Scenario 3: USDC supply + max WETH borrow
./utils/scripts/03_SCENARIO_USDC_MAX_BORROW.sh

# Scenario 4: WBTC supply + withdraw
./utils/scripts/04_SCENARIO_WBTC_SUPPLY_WITHDRAW.sh

# Scenario 5: Liquidation
./utils/scripts/05_SCENARIO_LIQUIDATION.sh
```

## Using Individual Helper Scripts

### Example: Supply Tokens

```bash
./utils/helpers/01_SUPPLY.sh \
  --token WETH \
  --amount 10 \
  --account 0x20A43DbBDfd90ad4488D44693662e1d01EAa3A37 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Example: Query Balances

```bash
./utils/helpers/06_QUERY.sh \
  --account 0x20A43DbBDfd90ad4488D44693662e1d01EAa3A37 \
  --rpc-url $RPC_URL
```

### Example: Borrow Tokens

```bash
./utils/helpers/03_BORROW.sh \
  --token WETH \
  --amount 2 \
  --account 0x25e82A0b41c153fdB1b4e7fbA5Eb84B55DdD9406 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Example: Manipulate Oracle (for testing)

```bash
./utils/helpers/09_MANIPULATE_ORACLE.sh \
  --token USDC \
  --price 0.5 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --rpc-url $RPC_URL
```

## What Each Scenario Does

### Scenario 1: WETH Supply
- **Purpose**: Basic supply functionality
- **Flow**: Mint WETH → Supply to Aave → Query aWETH balance
- **Learns**: How to deposit and receive interest-bearing tokens

### Scenario 2: USDT Supply + Borrow
- **Purpose**: Collateralized borrowing
- **Flow**: Mint USDT → Supply as collateral → Borrow WETH → Query position
- **Learns**: Using collateral to borrow, safe LTV (~40%)

### Scenario 3: USDC Max Borrow
- **Purpose**: High leverage position
- **Flow**: Mint USDC → Supply → Borrow WETH at 80% LTV → Query
- **Learns**: Maximum borrowing capacity, liquidation risk

### Scenario 4: WBTC Supply + Withdraw
- **Purpose**: Basic withdrawal
- **Flow**: Mint WBTC → Supply → Withdraw partial amount → Query
- **Learns**: How to exit positions

### Scenario 5: Liquidation
- **Purpose**: Liquidation mechanism
- **Flow**:
  1. Query borrower's position (from Scenario 3)
  3. Liquidator mints WETH
  4. Execute liquidation
  5. Query both positions
- **Learns**: How liquidations work, liquidator profits

## Test Accounts

| # | Address | Private Key | Role |
|---|---------|-------------|------|
| 0 | `0x20A43DbBDfd90ad4488D44693662e1d01EAa3A37` | `0x6139...` | WETH Supplier |
| 1 | `0x25e82A0b41c153fdB1b4e7fbA5Eb84B55DdD9406` | `0x3393...` | USDT Supplier/Borrower |
| 2 | `0x04F7DFe1D37927aF036fCC1f4a2a2FAd3E9dEa5E` | `0xa355...` | USDC Max Borrower |
| 3 | `0xAaBC76c120A3d435df5769728de43439fd6e16f2` | `0x9169...` | WBTC Supplier |
| 4 | `0x9eFe8259f16377579Ad4C28e944f06c9376E2b7F` | `0x2dcc...` | Liquidator |

## Features

**Pure Bash** - No Node.js required during execution
**Named Parameters** - Clear, readable command-line flags
**Detailed Errors** - Helpful error messages with suggestions
**Auto-Approval** - Automatically approves tokens when needed
**Human Readable** - Clean console output with emojis and formatting
**Modular** - Atomic operations can be combined for custom tests
**Complete** - Tests supply, withdraw, borrow, repay, liquidate, query

## Contract Addresses (Auto-Loaded)

All deployed contract addresses are automatically loaded from:
```
deployments/sepolia/*.json
```

Key contracts:
- **Pool**: `0xB4a571274EfeDcEed555EF92Dc24C5333174FFE8`
- **PoolDataProvider**: `0x4412a2B040d8Ea75ECe75948e626261899389E8d`
- **WETH Token**: `0x1614f877E9E585c7AeD706dd126F411E40087a77`
- **USDC Token**: `0xF50501a09549C65225f22D6F333Dcf255039b1Fd`
- **USDT Token**: `0x2E87d5b0Ac5c091407918FC5e541f6560b4F5172`

See `utils/helpers/load_addresses.sh` for complete list.
