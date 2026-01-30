#!/bin/bash

# 01_SCENARIO_WETH_SUPPLY.sh
# Scenario: Transfer WETH to Account 0, supply to Aave, query aWETH balance

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

# Test account info
ACCOUNT_0="0x20A43DbBDfd90ad4488D44693662e1d01EAa3A37"
ACCOUNT_0_KEY="0x6139b93733ecaae001a5953d79d4f90e9e3d1105875f82d0cdbb1591671b7afe"

# Test parameters
TOKEN="WETH"
AMOUNT="10"

echo "=================================================="
echo "SCENARIO 1: WETH Supply"
echo "=================================================="
echo "Account: $ACCOUNT_0"
echo "Token:   $TOKEN"
echo "Amount:  $AMOUNT"
echo "=================================================="
echo ""

# Step 1: Mint WETH to Account 0
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Minting $AMOUNT $TOKEN to Account 0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/08_MINT_TOKENS.sh" \
    --token "$TOKEN" \
    --amount "$AMOUNT" \
    --recipient "$ACCOUNT_0" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not mint tokens"
    exit 1
fi

echo ""

# Step 2: Supply WETH to Aave
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Supplying $AMOUNT $TOKEN to Aave"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/01_SUPPLY.sh" \
    --token "$TOKEN" \
    --amount "$AMOUNT" \
    --account "$ACCOUNT_0" \
    --private-key "$ACCOUNT_0_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not supply tokens"
    exit 1
fi

echo ""

# Step 3: Query balances
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Querying Account 0 Balances"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$ACCOUNT_0" \
    --token "$TOKEN" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not query balances"
    exit 1
fi

echo ""
echo "=================================================="
echo "SCENARIO 1 COMPLETE!"
echo "=================================================="
echo ""
echo "Summary:"
echo "  ✓ Minted $AMOUNT $TOKEN to Account 0"
echo "  ✓ Supplied $AMOUNT $TOKEN to Aave"
echo "  ✓ Account 0 now has a$TOKEN (interest-bearing tokens)"
echo ""
