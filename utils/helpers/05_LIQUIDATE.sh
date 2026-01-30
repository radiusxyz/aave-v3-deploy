#!/bin/bash

# 05_LIQUIDATE.sh
# Liquidates an undercollateralized position

set -e

# Source helper scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/load_addresses.sh"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Usage function
usage() {
    echo "Usage: $0 --collateral <TOKEN> --debt <TOKEN> --user <USER_ADDRESS> --amount <AMOUNT> --liquidator <LIQUIDATOR_ADDRESS> --private-key <PRIVATE_KEY>"
    echo ""
    echo "Required arguments:"
    echo "  --collateral     Collateral token to receive (WETH, DAI, USDC, USDT, WBTC, etc.)"
    echo "  --debt           Debt token to repay (WETH, DAI, USDC, USDT, WBTC, etc.)"
    echo "  --user           Address of the user to liquidate"
    echo "  --amount         Amount of debt to repay (in token decimals, use 'max' for max)"
    echo "  --liquidator     Address of the liquidator (who pays debt and receives collateral)"
    echo "  --private-key    Private key of the liquidator"
    echo ""
    echo "Optional arguments:"
    echo "  --receive-atoken Receive aToken instead of underlying (true/false, default: false)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --collateral USDC --debt WETH --user 0xabc... --amount 1 --liquidator 0x123... --private-key 0xdef..."
    exit 1
}

RECEIVE_ATOKEN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --collateral)
            COLLATERAL="$2"
            shift 2
            ;;
        --debt)
            DEBT="$2"
            shift 2
            ;;
        --user)
            USER="$2"
            shift 2
            ;;
        --amount)
            AMOUNT="$2"
            shift 2
            ;;
        --liquidator)
            LIQUIDATOR="$2"
            shift 2
            ;;
        --private-key)
            PRIVATE_KEY="$2"
            shift 2
            ;;
        --receive-atoken)
            RECEIVE_ATOKEN="$2"
            shift 2
            ;;
        --rpc-url)
            RPC_URL="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo " ERROR: Unknown argument: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$COLLATERAL" ] || [ -z "$DEBT" ] || [ -z "$USER" ] || [ -z "$AMOUNT" ] || [ -z "$LIQUIDATOR" ] || [ -z "$PRIVATE_KEY" ]; then
    echo " ERROR: Missing required arguments"
    usage
fi

# Validate RPC_URL
if [ -z "$RPC_URL" ]; then
    echo " ERROR: RPC_URL not set. Please set it in .env file or pass via --rpc-url"
    exit 1
fi

# Get token addresses
COLLATERAL_ADDRESS=$(get_token_address "$COLLATERAL")
DEBT_ADDRESS=$(get_token_address "$DEBT")

if [ -z "$COLLATERAL_ADDRESS" ] || [ -z "$DEBT_ADDRESS" ]; then
    echo " ERROR: Invalid token symbol"
    echo "Valid tokens: WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS"
    exit 1
fi

# Determine debt token decimals
if [ "$DEBT" == "WBTC" ]; then
    DECIMALS=8
elif [ "$DEBT" == "USDC" ] || [ "$DEBT" == "USDT" ]; then
    DECIMALS=6
else
    DECIMALS=18
fi

# Calculate amount in wei
if [ "$AMOUNT" == "max" ]; then
    AMOUNT_WEI="115792089237316195423570985008687907853269984665640564039457584007913129639935"
    AMOUNT_DISPLAY="MAX"
else
    AMOUNT_WEI=$(echo "$AMOUNT * 10^$DECIMALS" | bc | cut -d'.' -f1)
    AMOUNT_DISPLAY="$AMOUNT $DEBT"
fi

echo "=================================================="
echo "⚡ Liquidating Position"
echo "=================================================="
echo "User:              $USER"
echo "Liquidator:        $LIQUIDATOR"
echo "Debt Token:        $DEBT ($DEBT_ADDRESS)"
echo "Collateral Token:  $COLLATERAL ($COLLATERAL_ADDRESS)"
echo "Debt to Repay:     $AMOUNT_DISPLAY ($AMOUNT_WEI wei)"
echo "Receive aToken:    $RECEIVE_ATOKEN"
echo "Pool:              $POOL_PROXY"
echo "=================================================="
echo ""

# Check liquidator has enough debt tokens
echo "Checking liquidator balance..."
LIQUIDATOR_BALANCE=$(cast call "$DEBT_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$LIQUIDATOR" \
    --rpc-url "$RPC_URL")
echo "Liquidator $DEBT balance: $LIQUIDATOR_BALANCE wei"

if [ "$AMOUNT" != "max" ] && [ "$LIQUIDATOR_BALANCE" -lt "$AMOUNT_WEI" ]; then
    echo ""
    echo " ERROR: Liquidator has insufficient $DEBT balance"
    echo "Required: $AMOUNT_WEI wei"
    echo "Available: $LIQUIDATOR_BALANCE wei"
    exit 1
fi

# Check and approve if needed
echo "Checking allowance..."
ALLOWANCE=$(cast call "$DEBT_ADDRESS" \
    "allowance(address,address)(uint256)" \
    "$LIQUIDATOR" \
    "$POOL_PROXY" \
    --rpc-url "$RPC_URL")

if [ "$AMOUNT" != "max" ] && [ "$ALLOWANCE" -lt "$AMOUNT_WEI" ]; then
    echo "Insufficient allowance. Approving tokens..."
    "$SCRIPT_DIR/07_APPROVE.sh" \
        --token "$DEBT" \
        --spender "$POOL_PROXY" \
        --account "$LIQUIDATOR" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC_URL"
    echo ""
fi

# Execute liquidation
echo " Sending liquidation transaction..."
TX_HASH=$(cast send "$POOL_PROXY" \
    "liquidationCall(address,address,address,uint256,bool)" \
    "$COLLATERAL_ADDRESS" \
    "$DEBT_ADDRESS" \
    "$USER" \
    "$AMOUNT_WEI" \
    "$RECEIVE_ATOKEN" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo " ERROR: Liquidation transaction failed"
    echo "User: $USER"
    echo "Debt: $DEBT ($DEBT_ADDRESS)"
    echo "Collateral: $COLLATERAL ($COLLATERAL_ADDRESS)"
    echo "Amount: $AMOUNT_WEI wei"
    echo ""
    echo "Possible reasons:"
    echo "  - User's health factor is above 1 (position is healthy)"
    echo "  - Liquidator has insufficient debt tokens"
    echo "  - Debt token not approved"
    echo "  - Invalid liquidation amount"
    echo "  - Insufficient gas"
    echo ""
    echo "To make position liquidatable, try:"
    echo "  ./utils/helpers/09_MANIPULATE_ORACLE.sh --token $COLLATERAL --price <LOWER_PRICE>"
    exit 1
fi

echo "Liquidation transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 3

echo "Liquidation complete!"
echo "The liquidator repaid $AMOUNT_DISPLAY and received $COLLATERAL collateral"
