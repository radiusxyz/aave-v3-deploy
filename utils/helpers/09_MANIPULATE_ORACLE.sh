#!/bin/bash

# 09_MANIPULATE_ORACLE.sh
# Manipulates oracle price for testing (TESTNET ONLY!)

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
    echo "Usage: $0 --token <TOKEN> --price <PRICE> --private-key <PRIVATE_KEY>"
    echo ""
    echo "WARNING: This is for TESTNET ONLY! Do not use on mainnet!"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --price          New price in USD (e.g., 2000 for \$2000)"
    echo "  --private-key    Private key with oracle admin rights (deployer)"
    echo ""
    echo "Optional arguments:"
    echo "  --decimals       Oracle decimals (default: 8)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --price 2000 --private-key 0xabc..."
    echo "  $0 --token USDC --price 0.5 --private-key 0xabc...  # 50% price drop"
    exit 1
}

# Default oracle decimals (Chainlink standard is 8)
ORACLE_DECIMALS=8

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --price)
            PRICE="$2"
            shift 2
            ;;
        --private-key)
            PRIVATE_KEY="$2"
            shift 2
            ;;
        --decimals)
            ORACLE_DECIMALS="$2"
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
if [ -z "$TOKEN" ] || [ -z "$PRICE" ] || [ -z "$PRIVATE_KEY" ]; then
    echo " ERROR: Missing required arguments"
    usage
fi

# Validate RPC_URL
if [ -z "$RPC_URL" ]; then
    echo " ERROR: RPC_URL not set. Please set it in .env file or pass via --rpc-url"
    exit 1
fi

# Get oracle address
ORACLE_ADDRESS=$(get_oracle_address "$TOKEN")
if [ -z "$ORACLE_ADDRESS" ]; then
    echo " ERROR: Invalid token symbol: $TOKEN"
    echo "Valid tokens: WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS"
    exit 1
fi

# Calculate price with decimals (oracle uses 8 decimals typically)
PRICE_WEI=$(echo "$PRICE * 10^$ORACLE_DECIMALS" | bc | cut -d'.' -f1)

echo "=================================================="
echo "MANIPULATING ORACLE PRICE (TESTNET ONLY)"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Oracle Address:  $ORACLE_ADDRESS"
echo "New Price:       \$$PRICE"
echo "Price (wei):     $PRICE_WEI (with $ORACLE_DECIMALS decimals)"
echo "=================================================="
echo ""

# Get current price
echo "Checking current oracle price..."
CURRENT_PRICE_RAW=$(cast call "$ORACLE_ADDRESS" \
    "latestAnswer()(int256)" \
    --rpc-url "$RPC_URL")
CURRENT_PRICE=$(echo "$CURRENT_PRICE_RAW" | awk '{print $1}')
CURRENT_PRICE_USD=$(echo "scale=2; $CURRENT_PRICE / 10^$ORACLE_DECIMALS" | bc)
echo "Current price: \$$CURRENT_PRICE_USD ($CURRENT_PRICE wei)"
echo ""

# ERROR: MockAggregator doesn't support price updates
echo ""
echo "================================================================"
echo " LIMITATION: Oracle Price Manipulation Not Supported"
echo "================================================================"
echo ""
echo "The deployed MockAggregator contracts are immutable and cannot"
echo "have their prices updated after deployment."
echo ""
echo "MockAggregator.sol only sets the price in the constructor:"
echo "  constructor(int256 initialAnswer) {"
echo "    _latestAnswer = initialAnswer;"
echo "  }"
echo ""
echo "There is no updateAnswer() or setAnswer() function available."
echo ""
echo "================================================================"
echo "Alternative Approaches for Testing Liquidations:"
echo "================================================================"
echo ""
echo "1. MANUAL UNDERCOLLATERALIZATION:"
echo "   - Borrow very close to max LTV (e.g., 79.9% of 80% LTV)"
echo "   - Wait for interest to accrue"
echo "   - Position becomes liquidatable naturally"
echo ""
echo "2. DEPLOY CUSTOM ORACLES:"
echo "   - Modify deployment to use a different mock oracle"
echo "   - Use PriceOracle.sol which has setAssetPrice()"
echo "   - Requires re-deployment"
echo ""
echo "3. MANIPULATE VIA AAVE ORACLE:"
echo "   - Deploy new MockAggregator with different price"
echo "   - Call AaveOracle.setAssetSources() to update source"
echo "   - Requires admin access to AaveOracle"
echo ""
echo "================================================================"
echo ""
echo "For now, skipping price manipulation..."
echo "The liquidation scenario will only work if the position"
echo "is already undercollateralized."
echo ""

# Exit with code 2 to indicate "skip" rather than "failure"
exit 2

echo "Oracle update transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 3

# Verify new price
echo "Verifying new price..."
NEW_PRICE_RAW=$(cast call "$ORACLE_ADDRESS" \
    "latestAnswer()(int256)" \
    --rpc-url "$RPC_URL")
NEW_PRICE=$(echo "$NEW_PRICE_RAW" | awk '{print $1}')
NEW_PRICE_USD=$(echo "scale=2; $NEW_PRICE / 10^$ORACLE_DECIMALS" | bc)
echo "New price: \$$NEW_PRICE_USD ($NEW_PRICE wei)"
echo ""

if [ "$NEW_PRICE" == "$PRICE_WEI" ]; then
    echo "Oracle price updated successfully!"
    echo ""
    echo "📊 Price Change Summary:"
    echo "  From: \$$CURRENT_PRICE_USD"
    echo "  To:   \$$NEW_PRICE_USD"

    # Calculate percentage change
    PERCENT_CHANGE=$(echo "scale=2; (($NEW_PRICE - $CURRENT_PRICE) / $CURRENT_PRICE) * 100" | bc)
    if [ "${PERCENT_CHANGE:0:1}" == "-" ]; then
        echo "  Change: $PERCENT_CHANGE% "
    else
        echo "  Change: +$PERCENT_CHANGE% "
    fi
else
    echo "WARNING: Price verification failed"
    echo "Expected: $PRICE_WEI"
    echo "Got: $NEW_PRICE"
fi
