#!/bin/bash

# 04_SCENARIO_WBTC_SUPPLY_WITHDRAW.sh
# Scenario: Supply WBTC, then immediately withdraw it

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
TOKEN="WBTC"
SUPPLY_AMOUNT="2"      # 2 WBTC (~$80,000 at $40k per BTC)
WITHDRAW_AMOUNT="1"    # Withdraw 1 WBTC

echo "=================================================="
echo "SCENARIO 4: WBTC Supply + Withdraw"
echo "=================================================="
echo "Account: $ACCOUNT_3"
echo "Token: $TOKEN"
echo "Supply: $SUPPLY_AMOUNT $TOKEN"
echo "Withdraw: $WITHDRAW_AMOUNT $TOKEN"
echo "=================================================="
echo ""

# Step 1: Mint WBTC to Account 3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Minting $SUPPLY_AMOUNT $TOKEN to Account 3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/08_MINT_TOKENS.sh" \
    --token "$TOKEN" \
    --amount "$SUPPLY_AMOUNT" \
    --recipient "$ACCOUNT_3" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not mint tokens"
    exit 1
fi

echo ""

# Step 2: Supply WBTC to Aave
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Supplying $SUPPLY_AMOUNT $TOKEN to Aave"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/01_SUPPLY.sh" \
    --token "$TOKEN" \
    --amount "$SUPPLY_AMOUNT" \
    --account "$ACCOUNT_3" \
    --private-key "$ACCOUNT_3_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not supply tokens"
    exit 1
fi

echo ""

# Step 3: Query balances after supply
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Querying Balance After Supply"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$ACCOUNT_3" \
    --token "$TOKEN" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not query balances"
    exit 1
fi

echo ""

# Step 4: Withdraw WBTC from Aave
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Withdrawing $WITHDRAW_AMOUNT $TOKEN from Aave"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/02_WITHDRAW.sh" \
    --token "$TOKEN" \
    --amount "$WITHDRAW_AMOUNT" \
    --account "$ACCOUNT_3" \
    --private-key "$ACCOUNT_3_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not withdraw tokens"
    exit 1
fi

echo ""

# Step 5: Query final balances
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Querying Final Balance After Withdraw"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$ACCOUNT_3" \
    --token "$TOKEN" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not query balances"
    exit 1
fi

echo ""
echo "=================================================="
echo "SCENARIO 4 COMPLETE!"
echo "=================================================="
echo ""
echo "Summary:"
echo "  Supplied $SUPPLY_AMOUNT $TOKEN to Aave"
echo "  Received a$TOKEN (interest-bearing tokens)"
echo "  Withdrew $WITHDRAW_AMOUNT $TOKEN back to wallet"
echo "  Remaining: $((SUPPLY_AMOUNT - WITHDRAW_AMOUNT)) $TOKEN in Aave"
echo ""
echo "This demonstrates the basic deposit/withdrawal flow"
echo ""
