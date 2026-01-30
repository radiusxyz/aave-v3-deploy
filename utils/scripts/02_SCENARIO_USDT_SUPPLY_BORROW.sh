#!/bin/bash

# 02_SCENARIO_USDT_SUPPLY_BORROW.sh
# Scenario: Supply USDT as collateral, borrow WETH (less than 50% of collateral value)

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
LIQUIDITY_TOKEN="DAI"
LIQUIDITY_AMOUNT="1000"  # Supply 1000 DAI as liquidity for borrowing
COLLATERAL_TOKEN="USDT"
COLLATERAL_AMOUNT="500"  # $500 worth of USDT
BORROW_TOKEN="DAI"
# USDT is an isolation mode asset with a debt ceiling
# We can only borrow assets with borrowableIsolation: true (like DAI)
# Using conservative LTV of ~30%: $500 * 0.3 = 150 DAI
BORROW_AMOUNT="150"

echo "=================================================="
echo "SCENARIO 2: USDT Supply + DAI Borrow (Isolation Mode)"
echo "=================================================="
echo "Liquidity Provider: $ACCOUNT_0"
echo "Borrower: $ACCOUNT_1"
echo "Liquidity: $LIQUIDITY_AMOUNT $LIQUIDITY_TOKEN"
echo "Collateral: $COLLATERAL_AMOUNT $COLLATERAL_TOKEN"
echo "Borrow: $BORROW_AMOUNT $BORROW_TOKEN"
echo "=================================================="
echo ""

# Step 1: Mint and supply DAI liquidity from Account 0
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

# Step 2: Mint USDT to Account 1
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Minting $COLLATERAL_AMOUNT $COLLATERAL_TOKEN to Account 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/08_MINT_TOKENS.sh" \
    --token "$COLLATERAL_TOKEN" \
    --amount "$COLLATERAL_AMOUNT" \
    --recipient "$ACCOUNT_1" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not mint tokens"
    exit 1
fi

echo ""

# Step 3: Supply USDT to Aave
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Supplying $COLLATERAL_AMOUNT $COLLATERAL_TOKEN to Aave"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/01_SUPPLY.sh" \
    --token "$COLLATERAL_TOKEN" \
    --amount "$COLLATERAL_AMOUNT" \
    --account "$ACCOUNT_1" \
    --private-key "$ACCOUNT_1_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo "SCENARIO FAILED: Could not supply collateral"
    exit 1
fi

echo ""

# Step 4: Enable USDT as collateral
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Enabling $COLLATERAL_TOKEN as collateral"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/11_SET_USE_AS_COLLATERAL.sh" \
    --token "$COLLATERAL_TOKEN" \
    --account "$ACCOUNT_1" \
    --private-key "$ACCOUNT_1_KEY" \
    --enable true \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo "SCENARIO FAILED: Could not enable collateral"
    exit 1
fi

echo ""

# Step 5: Borrow DAI
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Borrowing $BORROW_AMOUNT $BORROW_TOKEN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/03_BORROW.sh" \
    --token "$BORROW_TOKEN" \
    --amount "$BORROW_AMOUNT" \
    --account "$ACCOUNT_1" \
    --private-key "$ACCOUNT_1_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo "SCENARIO FAILED: Could not borrow tokens"
    exit 1
fi

echo ""

# Step 6: Query all balances
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Querying Account 1 Full Position"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$ACCOUNT_1" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo "SCENARIO FAILED: Could not query balances"
    exit 1
fi

echo ""
echo "=================================================="
echo "SCENARIO 2 COMPLETE!"
echo "=================================================="
echo ""
echo "Summary:"
echo "  ✓ Account 0 supplied $LIQUIDITY_AMOUNT $LIQUIDITY_TOKEN as liquidity"
echo "  ✓ Account 1 supplied $COLLATERAL_AMOUNT $COLLATERAL_TOKEN as collateral"
echo "  ✓ Account 1 enabled $COLLATERAL_TOKEN as collateral (isolation mode)"
echo "  ✓ Account 1 borrowed $BORROW_AMOUNT $BORROW_TOKEN against collateral"
echo "  "
echo "  Account 0 has:"
echo "    - a$LIQUIDITY_TOKEN (earning interest on supplied DAI)"
echo "  "
echo "  Account 1 has:"
echo "    - a$COLLATERAL_TOKEN (collateral tokens)"
echo "    - $BORROW_AMOUNT $BORROW_TOKEN (borrowed tokens in wallet)"
echo "    - Variable debt tokens representing the loan"
echo ""
