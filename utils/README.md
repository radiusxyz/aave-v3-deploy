# Aave V3 Testing Scripts

This directory contains Bash scripts for testing Aave V3 functionality on Sepolia testnet using pure Bash and `cast` (from Foundry).

## Prerequisites

1. **Foundry** - Install cast:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **jq** - JSON processor:
   ```bash
   # macOS
   brew install jq

   # Linux
   sudo apt-get install jq
   ```

3. **bc** - Calculator for decimal arithmetic:
   ```bash
   # macOS (pre-installed)
   # Linux
   sudo apt-get install bc
   ```

4. **.env file** - Configure your environment variables:
   ```env
   RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_ALCHEMY_KEY
   DEPLOYER_PRIVATE_KEY=0x...
   ```

## Directory Structure

```
utils/
├── helpers/               # Atomic operation scripts (building blocks)
│   ├── load_addresses.sh  # Load deployed contract addresses
│   ├── load_abi.sh        # Extract ABIs from deployment files
│   ├── 01_SUPPLY.sh       # Supply tokens to Aave
│   ├── 02_WITHDRAW.sh     # Withdraw tokens from Aave
│   ├── 03_BORROW.sh       # Borrow tokens against collateral
│   ├── 04_REPAY.sh        # Repay borrowed tokens
│   ├── 05_LIQUIDATE.sh    # Liquidate undercollateralized positions
│   ├── 06_QUERY.sh        # Query user balances and positions
│   ├── 07_APPROVE.sh      # Approve token spending
│   ├── 08_MINT_TOKENS.sh  # Mint testnet tokens
│   └── 09_MANIPULATE_ORACLE.sh  # Change oracle prices (testnet only)
│
└── scripts/               # Test scenario scripts
    ├── 00_SETUP_ACCOUNTS.sh              # Fund test accounts
    ├── 01_SCENARIO_WETH_SUPPLY.sh        # Simple supply scenario
    ├── 02_SCENARIO_USDT_SUPPLY_BORROW.sh # Supply + borrow scenario
    ├── 03_SCENARIO_USDC_MAX_BORROW.sh    # Max leverage scenario
    ├── 04_SCENARIO_WBTC_SUPPLY_WITHDRAW.sh # Supply + withdraw scenario
    └── 05_SCENARIO_LIQUIDATION.sh        # Liquidation scenario
```

## Quick Start

### 1. Setup Test Accounts

Fund the 5 test accounts with ETH:

```bash
./utils/scripts/00_SETUP_ACCOUNTS.sh
```

This sends 0.5 ETH to each test account from the deployer.

### 2. Run Individual Scenarios

#### Scenario 1: WETH Supply
```bash
./utils/scripts/01_SCENARIO_WETH_SUPPLY.sh
```
- Mints 10 WETH to Account 0
- Supplies it to Aave
- Queries aWETH balance

#### Scenario 2: USDT Supply + WETH Borrow
```bash
./utils/scripts/02_SCENARIO_USDT_SUPPLY_BORROW.sh
```
- Supplies 10,000 USDT as collateral
- Borrows 2 WETH (~40% LTV)
- Queries full position

#### Scenario 3: USDC Max Borrow
```bash
./utils/scripts/03_SCENARIO_USDC_MAX_BORROW.sh
```
- Supplies 20,000 USDC
- Borrows 8 WETH at 80% LTV (risky!)
- Demonstrates max leverage

#### Scenario 4: WBTC Supply + Withdraw
```bash
./utils/scripts/04_SCENARIO_WBTC_SUPPLY_WITHDRAW.sh
```
- Supplies 2 WBTC
- Withdraws 1 WBTC back
- Shows deposit/withdrawal flow

#### Scenario 5: Liquidation
```bash
./utils/scripts/05_SCENARIO_LIQUIDATION.sh
```
- Takes the max-leveraged position from Scenario 3
- Drops USDC price by 50% (oracle manipulation)
- Liquidates the unhealthy position
- Shows liquidator profits

### 3. Run All Scenarios

```bash
# Run scenarios in order
for script in ./utils/scripts/0*.sh; do
    echo "Running $script..."
    $script
    echo ""
done
```

## Using Atomic Helper Scripts

The helper scripts can be used independently for custom testing:

### Supply Tokens
```bash
./utils/helpers/01_SUPPLY.sh \
  --token WETH \
  --amount 10 \
  --account 0x... \
  --private-key 0x...
```

### Withdraw Tokens
```bash
./utils/helpers/02_WITHDRAW.sh \
  --token WETH \
  --amount 5 \
  --account 0x... \
  --private-key 0x...
```

### Borrow Tokens
```bash
./utils/helpers/03_BORROW.sh \
  --token WETH \
  --amount 2 \
  --account 0x... \
  --private-key 0x...
```

### Query Position
```bash
./utils/helpers/06_QUERY.sh \
  --account 0x...
```

### Mint Testnet Tokens
```bash
./utils/helpers/08_MINT_TOKENS.sh \
  --token WETH \
  --amount 100 \
  --recipient 0x... \
  --private-key $DEPLOYER_PRIVATE_KEY
```

### Manipulate Oracle Price (Testnet Only!)
```bash
./utils/helpers/09_MANIPULATE_ORACLE.sh \
  --token WETH \
  --price 2000 \
  --private-key $DEPLOYER_PRIVATE_KEY
```

## Test Accounts

The scripts use these pre-configured accounts:

| Account | Address | Purpose |
|---------|---------|---------|
| Account 0 | `0x20A43DbBDfd90ad4488D44693662e1d01EAa3A37` | WETH Supply |
| Account 1 | `0x25e82A0b41c153fdB1b4e7fbA5Eb84B55DdD9406` | USDT Supply/Borrow |
| Account 2 | `0x04F7DFe1D37927aF036fCC1f4a2a2FAd3E9dEa5E` | USDC Max Borrow |
| Account 3 | `0xAaBC76c120A3d435df5769728de43439fd6e16f2` | WBTC Supply/Withdraw |
| Account 4 | `0x9eFe8259f16377579Ad4C28e944f06c9376E2b7F` | Liquidator |

## Supported Tokens

- WETH - Wrapped Ether
- DAI - Dai Stablecoin
- USDC - USD Coin
- USDT - Tether USD
- WBTC - Wrapped Bitcoin
- LINK - Chainlink
- AAVE - Aave Token
- EURS - STASIS EURS

## Troubleshooting

### "RPC_URL not set"
Make sure your `.env` file contains:
```env
RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
```

### "jq: command not found"
Install jq:
```bash
brew install jq  # macOS
sudo apt-get install jq  # Linux
```

### "cast: command not found"
Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Transaction Failures
- Check you have enough ETH for gas
- Ensure tokens are approved before supply/borrow
- Verify account balances with `06_QUERY.sh`

### Liquidation Not Working
- Position might still be healthy (HF > 1)
- Try dropping collateral price more: `--price 0.3`
- Or increase debt token price

## How It Works

1. **Pure Bash + Cast**: All interactions use `cast` (Foundry) for blockchain operations
2. **ABI Loading**: Extracts ABIs from deployment JSON files
3. **Address Resolution**: Automatically loads contract addresses from `deployments/sepolia/`
4. **Error Handling**: Detailed error messages with suggestions
5. **Human Readable**: Clean console output with progress indicators

## Architecture

```
Scenario Script
    ↓
Calls Multiple Helper Scripts
    ↓
Helper Scripts Use:
    • load_addresses.sh (contract addresses)
    • cast send (write transactions)
    • cast call (read data)
    ↓
Interact with Aave V3 Contracts
```

## Safety Notes

⚠️ **TESTNET ONLY**
- These scripts are for Sepolia testnet only
- Never use on mainnet
- Private keys are exposed in plain text
- Oracle manipulation is only for testing

## Contributing

To add new scenarios:

1. Create a new script in `utils/scripts/`
2. Use numeric prefix: `06_SCENARIO_NEW_TEST.sh`
3. Source helper scripts from `../helpers/`
4. Follow existing patterns for error handling
5. Add comprehensive logging

## License

Same as the main Aave V3 deploy repository.
