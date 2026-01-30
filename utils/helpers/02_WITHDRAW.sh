#!/bin/bash

# 02_WITHDRAW.sh
# Withdraws tokens from Aave Pool

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
    echo "Usage: $0 --token <TOKEN> --amount <AMOUNT> --account <ACCOUNT_ADDRESS> --private-key <PRIVATE_KEY>"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol to withdraw (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --amount         Amount to withdraw (in token decimals, use 'max' for all)"
    echo "  --account        Account address withdrawing the tokens"
    echo "  --private-key    Private key of the account"
    echo ""
    echo "Optional arguments:"
    echo "  --to             Address to receive the tokens (default: same as account)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --amount 5 --account 0x123... --private-key 0xabc..."
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
        --to)
            TO="$2"
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

# Default to to account
if [ -z "$TO" ]; then
    TO="$ACCOUNT"
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

# Get aToken address
ATOKEN_ADDRESS=$(get_atoken_address "$TOKEN")

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

echo "=================================================="
echo "💸 Withdrawing from Aave Pool"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Amount:          $AMOUNT_DISPLAY ($AMOUNT_WEI wei)"
echo "Account:         $ACCOUNT"
echo "Recipient:       $TO"
echo "Pool:            $POOL_PROXY"
echo "aToken:          $ATOKEN_ADDRESS"
echo "=================================================="
echo ""

# Check aToken balance before
echo "Checking aToken balance..."
ATOKEN_BALANCE=$(cast call "$ATOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ACCOUNT" \
    --rpc-url "$RPC_URL")
echo "aToken balance: $ATOKEN_BALANCE wei"

if [ "$ATOKEN_BALANCE" == "0" ]; then
    echo ""
    echo " ERROR: No aToken balance to withdraw"
    echo "Account has 0 a$TOKEN"
    echo ""
    echo "Suggestion: Supply tokens first using:"
    echo "  ./utils/helpers/01_SUPPLY.sh --token $TOKEN --amount <AMOUNT> --account $ACCOUNT"
    exit 1
fi

# Execute withdrawal
echo " Sending withdrawal transaction..."
TX_HASH=$(cast send "$POOL_PROXY" \
    "withdraw(address,uint256,address)" \
    "$TOKEN_ADDRESS" \
    "$AMOUNT_WEI" \
    "$TO" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo " ERROR: Withdrawal transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Amount: $AMOUNT_WEI wei"
    echo "Account: $ACCOUNT"
    echo "Pool: $POOL_PROXY"
    echo ""
    echo "Possible reasons:"
    echo "  - Insufficient aToken balance"
    echo "  - Amount exceeds available liquidity"
    echo "  - Health factor would drop below 1 (if borrowed)"
    echo "  - Insufficient gas"
    exit 1
fi

echo "Withdrawal transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 3

# Check balances after
echo "Verifying balances..."
TOKEN_BALANCE=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$TO" \
    --rpc-url "$RPC_URL")
ATOKEN_BALANCE_AFTER=$(cast call "$ATOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ACCOUNT" \
    --rpc-url "$RPC_URL")

echo "Token balance:        $TOKEN_BALANCE wei"
echo "aToken balance after: $ATOKEN_BALANCE_AFTER wei"
echo ""
echo "Withdrawal complete!"
