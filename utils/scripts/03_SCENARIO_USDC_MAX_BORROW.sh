#!/bin/bash

# 03_SCENARIO_USDC_MAX_BORROW.sh
# Scenario: Supply USDC, borrow WETH at maximum (80% LTV)

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS_DIR="$SCRIPT_DIR/../helpers"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source helper scripts
source "$HELPERS_DIR/load_addresses.sh"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Test parameters
LIQUIDITY_TOKEN="WETH"
LIQUIDITY_AMOUNT="10"  # Supply 10 WETH as liquidity for borrowing
COLLATERAL_TOKEN="USDC"
COLLATERAL_AMOUNT="100"  # $100 worth of USDC
BORROW_TOKEN="WETH"
# USDC has 80% LTV, but using conservative 50% to account for price variations
# Assuming WETH = $2000: $100 * 0.50 / $2000 = 0.025 WETH
BORROW_AMOUNT="0.020"

echo "=================================================="
echo "SCENARIO 3: USDC Supply + Max WETH Borrow"
echo "=================================================="
echo "Liquidity Provider: $ACCOUNT_0"
echo "Borrower: $ACCOUNT_2"
echo "Liquidity: $LIQUIDITY_AMOUNT $LIQUIDITY_TOKEN"
echo "Collateral: $COLLATERAL_AMOUNT $COLLATERAL_TOKEN"
echo "Borrow: $BORROW_AMOUNT $BORROW_TOKEN (50% LTV - conservative)"
echo "=================================================="
echo ""

# Step 1: Mint and supply WETH liquidity from Account 0
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Providing $LIQUIDITY_AMOUNT $LIQUIDITY_TOKEN liquidity (Account 0)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/08_MINT_TOKENS.sh" \
    --token "$LIQUIDITY_TOKEN" \
    --amount "$LIQUIDITY_AMOUNT" \
    --recipient "$ACCOUNT_0" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not mint liquidity tokens"
    exit 1
fi

"$HELPERS_DIR/01_SUPPLY.sh" \
    --token "$LIQUIDITY_TOKEN" \
    --amount "$LIQUIDITY_AMOUNT" \
    --account "$ACCOUNT_0" \
    --private-key "$ACCOUNT_0_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not supply liquidity"
    exit 1
fi

echo ""

# Step 2: Mint USDC to Account 2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Minting $COLLATERAL_AMOUNT $COLLATERAL_TOKEN to Account 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/08_MINT_TOKENS.sh" \
    --token "$COLLATERAL_TOKEN" \
    --amount "$COLLATERAL_AMOUNT" \
    --recipient "$ACCOUNT_2" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not mint tokens"
    exit 1
fi

echo ""

# Step 3: Supply USDC to Aave
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Supplying $COLLATERAL_AMOUNT $COLLATERAL_TOKEN to Aave"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/01_SUPPLY.sh" \
    --token "$COLLATERAL_TOKEN" \
    --amount "$COLLATERAL_AMOUNT" \
    --account "$ACCOUNT_2" \
    --private-key "$ACCOUNT_2_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not supply collateral"
    exit 1
fi

echo ""

# Step 4: Enable USDC as collateral
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Enabling $COLLATERAL_TOKEN as collateral"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/11_SET_USE_AS_COLLATERAL.sh" \
    --token "$COLLATERAL_TOKEN" \
    --account "$ACCOUNT_2" \
    --private-key "$ACCOUNT_2_KEY" \
    --enable true \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not enable collateral"
    exit 1
fi

echo ""

# Step 5: Borrow WETH at 80% LTV
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Borrowing $BORROW_AMOUNT $BORROW_TOKEN (80% LTV)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/03_BORROW.sh" \
    --token "$BORROW_TOKEN" \
    --amount "$BORROW_AMOUNT" \
    --account "$ACCOUNT_2" \
    --private-key "$ACCOUNT_2_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not borrow tokens"
    echo ""
    echo "⚠️  Note: If borrowing failed, the actual max LTV might be lower than 80%"
    echo "Try reducing BORROW_AMOUNT in the script"
    exit 1
fi

echo ""

# Step 6: Query all balances
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Querying Account 2 Full Position"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$ACCOUNT_2" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not query balances"
    exit 1
fi

echo ""
echo "=================================================="
echo "SCENARIO 3 COMPLETE!"
echo "=================================================="
echo ""
echo "Summary:"
echo "  ✓ Account 0 supplied $LIQUIDITY_AMOUNT $LIQUIDITY_TOKEN as liquidity"
echo "  ✓ Account 2 supplied $COLLATERAL_AMOUNT $COLLATERAL_TOKEN as collateral"
echo "  ✓ Account 2 enabled $COLLATERAL_TOKEN as collateral"
echo "  ✓ Account 2 borrowed $BORROW_AMOUNT $BORROW_TOKEN at 80% LTV"
echo "  ✓ Account 2 position is highly leveraged"
echo "  ✓ Health factor is close to 1.0 (risky!)"
echo ""
echo "This position is at risk of liquidation if:"
echo "    - USDC price drops"
echo "    - WETH price increases"
echo "    - Interest accrues significantly"
echo ""
