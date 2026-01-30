#!/bin/bash

# 04_REPAY.sh
# Repays borrowed tokens to Aave Pool

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

# Default interest rate mode (2 = variable)
INTEREST_RATE_MODE=2

# Usage function
usage() {
    echo "Usage: $0 --token <TOKEN> --amount <AMOUNT> --account <ACCOUNT_ADDRESS> --private-key <PRIVATE_KEY>"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol to repay (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --amount         Amount to repay (in token decimals, use 'max' for all debt)"
    echo "  --account        Account address repaying the tokens"
    echo "  --private-key    Private key of the account"
    echo ""
    echo "Optional arguments:"
    echo "  --interest-mode  Interest rate mode: 1=stable, 2=variable (default: 2)"
    echo "  --on-behalf-of   Address whose debt to repay (default: same as account)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --amount 2 --account 0x123... --private-key 0xabc..."
    echo "  $0 --token WETH --amount max --account 0x123... --private-key 0xabc..."
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --amount)
            AMOUNT="$2"
            shift 2
            ;;
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --private-key)
            PRIVATE_KEY="$2"
            shift 2
            ;;
        --interest-mode)
            INTEREST_RATE_MODE="$2"
            shift 2
            ;;
        --on-behalf-of)
            ON_BEHALF_OF="$2"
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
if [ -z "$TOKEN" ] || [ -z "$AMOUNT" ] || [ -z "$ACCOUNT" ] || [ -z "$PRIVATE_KEY" ]; then
    echo " ERROR: Missing required arguments"
    usage
fi

# Default on-behalf-of to account
if [ -z "$ON_BEHALF_OF" ]; then
    ON_BEHALF_OF="$ACCOUNT"
fi

# Validate RPC_URL
if [ -z "$RPC_URL" ]; then
    echo " ERROR: RPC_URL not set. Please set it in .env file or pass via --rpc-url"
    exit 1
fi

# Get token address
TOKEN_ADDRESS=$(get_token_address "$TOKEN")
if [ -z "$TOKEN_ADDRESS" ]; then
    echo " ERROR: Invalid token symbol: $TOKEN"
    echo "Valid tokens: WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS"
    exit 1
fi

# Determine decimals
if [ "$TOKEN" == "WBTC" ]; then
    DECIMALS=8
elif [ "$TOKEN" == "USDC" ] || [ "$TOKEN" == "USDT" ]; then
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
    AMOUNT_DISPLAY="$AMOUNT $TOKEN"
fi

# Interest rate mode description
if [ "$INTEREST_RATE_MODE" == "1" ]; then
    RATE_MODE_DESC="Stable"
else
    RATE_MODE_DESC="Variable"
fi

echo "=================================================="
echo "Repaying Debt to Aave Pool"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Amount:          $AMOUNT_DISPLAY ($AMOUNT_WEI wei)"
echo "Account:         $ACCOUNT"
echo "On Behalf Of:    $ON_BEHALF_OF"
echo "Interest Mode:   $RATE_MODE_DESC ($INTEREST_RATE_MODE)"
echo "Pool:            $POOL_PROXY"
echo "=================================================="
echo ""

# Check allowance
echo "Checking allowance..."
ALLOWANCE=$(cast call "$TOKEN_ADDRESS" \
    "allowance(address,address)(uint256)" \
    "$ACCOUNT" \
    "$POOL_PROXY" \
    --rpc-url "$RPC_URL")

if [ "$AMOUNT" != "max" ] && [ "$ALLOWANCE" -lt "$AMOUNT_WEI" ]; then
    echo "Insufficient allowance. Approving tokens..."
    "$SCRIPT_DIR/07_APPROVE.sh" \
        --token "$TOKEN" \
        --spender "$POOL_PROXY" \
        --account "$ACCOUNT" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC_URL"
    echo ""
fi

# Execute repayment
echo " Sending repayment transaction..."
TX_HASH=$(cast send "$POOL_PROXY" \
    "repay(address,uint256,uint256,address)" \
    "$TOKEN_ADDRESS" \
    "$AMOUNT_WEI" \
    "$INTEREST_RATE_MODE" \
    "$ON_BEHALF_OF" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo " ERROR: Repayment transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Amount: $AMOUNT_WEI wei"
    echo "Account: $ACCOUNT"
    echo ""
    echo "Possible reasons:"
    echo "  - Insufficient token balance"
    echo "  - No debt to repay"
    echo "  - Token not approved"
    echo "  - Insufficient gas"
    exit 1
fi

echo "Repayment transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""
echo "Repayment complete!"
