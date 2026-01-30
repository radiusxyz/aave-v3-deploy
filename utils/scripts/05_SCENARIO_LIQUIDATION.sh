#!/bin/bash

# 05_SCENARIO_LIQUIDATION.sh
# Scenario: Liquidate the max-leveraged USDC borrower position

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

# Account info
BORROWER="0x04F7DFe1D37927aF036fCC1f4a2a2FAd3E9dEa5E"  # Account 2 from scenario 3


# Position details (from scenario 3)
COLLATERAL_TOKEN="USDC"
DEBT_TOKEN="WETH"
LIQUIDATION_AMOUNT="4"  # Liquidate half of the 8 WETH debt

echo "=================================================="
echo "SCENARIO 5: Position Liquidation"
echo "=================================================="
echo "Borrower:    $BORROWER (Account 2)"
echo "Liquidator:  $LIQUIDATOR (Account 4)"
echo "Collateral:  $COLLATERAL_TOKEN"
echo "Debt:        $DEBT_TOKEN"
echo "Amount:      $LIQUIDATION_AMOUNT $DEBT_TOKEN"
echo "=================================================="
echo ""

# Step 1: Check borrower position before manipulation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Checking Borrower Position (Before)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$BORROWER" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not query borrower position"
    exit 1
fi

echo ""

# Step 2: Manipulate USDC price to make position unhealthy
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Manipulating Oracle Price"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Dropping USDC price by 50% to trigger liquidation..."
echo ""

# Drop USDC price from $1.00 to $0.50
"$HELPERS_DIR/09_MANIPULATE_ORACLE.sh" \
    --token "$COLLATERAL_TOKEN" \
    --price "0.50" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

ORACLE_RESULT=$?
if [ $ORACLE_RESULT -eq 2 ]; then
    echo " Price manipulation not supported - continuing anyway"
    echo " Position must already be undercollateralized for liquidation to work"
elif [ $ORACLE_RESULT -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Unexpected error manipulating oracle"
    exit 1
fi

echo ""

# Step 3: Mint WETH to liquidator
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Preparing Liquidator ($LIQUIDATION_AMOUNT $DEBT_TOKEN)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/08_MINT_TOKENS.sh" \
    --token "$DEBT_TOKEN" \
    --amount "$LIQUIDATION_AMOUNT" \
    --recipient "$LIQUIDATOR" \
    --private-key "$DEPLOYER_PRIVATE_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not mint tokens to liquidator"
    exit 1
fi

echo ""

# Step 4: Check liquidator balance before
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 4: Liquidator Position (Before Liquidation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$LIQUIDATOR" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Could not query liquidator position"
    exit 1
fi

echo ""

# Step 5: Execute liquidation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: Executing Liquidation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/05_LIQUIDATE.sh" \
    --collateral "$COLLATERAL_TOKEN" \
    --debt "$DEBT_TOKEN" \
    --user "$BORROWER" \
    --amount "$LIQUIDATION_AMOUNT" \
    --liquidator "$LIQUIDATOR" \
    --private-key "$LIQUIDATOR_KEY" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo " SCENARIO FAILED: Liquidation transaction failed"
    echo ""
    echo "Possible reasons:"
    echo "  - Position is still healthy (health factor > 1)"
    echo "  - Try dropping USDC price even more"
    echo "  - Or increasing WETH price"
    exit 1
fi

echo ""

# Step 6: Check borrower position after liquidation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Borrower Position (After Liquidation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$BORROWER" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo "Warning: Could not query borrower position after liquidation"
fi

echo ""

# Step 7: Check liquidator position after liquidation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 7: Liquidator Position (After Liquidation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$HELPERS_DIR/06_QUERY.sh" \
    --account "$LIQUIDATOR" \
    --rpc-url "$RPC_URL"

if [ $? -ne 0 ]; then
    echo ""
    echo "Warning: Could not query liquidator position after liquidation"
fi

echo ""
echo "=================================================="
echo "SCENARIO 5 COMPLETE!"
echo "=================================================="
echo ""
echo "Summary:"
echo "  Borrower had max-leveraged position (80% LTV)"
echo "  USDC price dropped by 50% (oracle manipulation)"
echo "  Position became unhealthy (health factor < 1)"
echo "  Liquidator repaid $LIQUIDATION_AMOUNT $DEBT_TOKEN"
echo "  Liquidator received $COLLATERAL_TOKEN (+ liquidation bonus)"
echo "  Borrower's debt reduced, collateral partially seized"
echo ""
echo "Key Concepts Demonstrated:"
echo " Liquidations occur when health factor < 1"
echo " Liquidators repay borrower's debt"
echo " Liquidators receive collateral + bonus (~5-10%)"
echo " This keeps the protocol solvent"
echo ""
