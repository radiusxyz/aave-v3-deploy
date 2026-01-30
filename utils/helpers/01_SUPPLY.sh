#!/bin/bash

# 01_SUPPLY.sh
# Supplies tokens to Aave Pool

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
    echo "  --token          Token symbol to supply (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --amount         Amount to supply (in token decimals, e.g., 10 for 10 tokens)"
    echo "  --account        Account address supplying the tokens"
    echo "  --private-key    Private key of the account"
    echo ""
    echo "Optional arguments:"
    echo "  --on-behalf-of   Address to receive the aTokens (default: same as account)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --amount 10 --account 0x123... --private-key 0xabc..."
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

# Get aToken address
ATOKEN_ADDRESS=$(get_atoken_address "$TOKEN")

# Convert amount to wei (assuming 18 decimals for most tokens, 8 for WBTC)
if [ "$TOKEN" == "WBTC" ]; then
    DECIMALS=8
elif [ "$TOKEN" == "USDC" ] || [ "$TOKEN" == "USDT" ]; then
    DECIMALS=6
else
    DECIMALS=18
fi

# Calculate amount in wei
AMOUNT_WEI=$(echo "$AMOUNT * 10^$DECIMALS" | bc | cut -d'.' -f1)

echo "=================================================="
echo "Supplying to Aave Pool"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Amount:          $AMOUNT $TOKEN ($AMOUNT_WEI wei)"
echo "Account:         $ACCOUNT"
echo "On Behalf Of:    $ON_BEHALF_OF"
echo "Pool:            $POOL_PROXY"
echo "aToken:          $ATOKEN_ADDRESS"
echo "=================================================="
echo ""

# Check balance before
echo "Checking token balance..."
BALANCE_BEFORE_RAW=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ACCOUNT" \
    --rpc-url "$RPC_URL")
BALANCE_BEFORE=$(echo "$BALANCE_BEFORE_RAW" | awk '{print $1}')
echo "Balance before: $BALANCE_BEFORE wei"

if [ $(echo "$BALANCE_BEFORE < $AMOUNT_WEI" | bc) -eq 1 ]; then
    echo ""
    echo " ERROR: Insufficient balance"
    echo "Required: $AMOUNT_WEI wei"
    echo "Available: $BALANCE_BEFORE wei"
    echo ""
    echo "Suggestion: Mint tokens first using:"
    echo "  ./utils/helpers/08_MINT_TOKENS.sh --token $TOKEN --amount $AMOUNT --recipient $ACCOUNT"
    exit 1
fi

# Check allowance
echo "Checking allowance..."
ALLOWANCE_RAW=$(cast call "$TOKEN_ADDRESS" \
    "allowance(address,address)(uint256)" \
    "$ACCOUNT" \
    "$POOL_PROXY" \
    --rpc-url "$RPC_URL")
ALLOWANCE=$(echo "$ALLOWANCE_RAW" | awk '{print $1}')
echo "Current allowance: $ALLOWANCE wei"

if [ $(echo "$ALLOWANCE < $AMOUNT_WEI" | bc) -eq 1 ]; then
    echo ""
    echo "WARNING: Insufficient allowance"
    echo "Required: $AMOUNT_WEI wei"
    echo "Current:  $ALLOWANCE wei"
    echo ""
    echo "Approving tokens..."

    # Call approve script
    "$SCRIPT_DIR/07_APPROVE.sh" \
        --token "$TOKEN" \
        --spender "$POOL_PROXY" \
        --account "$ACCOUNT" \
        --private-key "$PRIVATE_KEY" \
        --rpc-url "$RPC_URL"

    echo ""
fi

# Execute supply
echo "Sending supply transaction..."
TX_HASH=$(cast send "$POOL_PROXY" \
    "supply(address,uint256,address,uint16)" \
    "$TOKEN_ADDRESS" \
    "$AMOUNT_WEI" \
    "$ON_BEHALF_OF" \
    0 \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo "ERROR: Supply transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Amount: $AMOUNT_WEI wei"
    echo "Account: $ACCOUNT"
    echo "Pool: $POOL_PROXY"
    echo ""
    echo "Possible reasons:"
    echo "  - Insufficient balance"
    echo "  - Insufficient gas"
    echo "  - Token not approved"
    echo "  - Reserve not active"
    exit 1
fi

echo "Supply transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 3

# Check balances after
echo "Verifying balances..."
BALANCE_AFTER=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ACCOUNT" \
    --rpc-url "$RPC_URL")
ATOKEN_BALANCE=$(cast call "$ATOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ON_BEHALF_OF" \
    --rpc-url "$RPC_URL")

echo "Token balance after:  $BALANCE_AFTER wei"
echo "aToken balance:       $ATOKEN_BALANCE wei"
echo ""
echo "Supply complete!"
echo "You supplied $AMOUNT $TOKEN and received aTokens at $ATOKEN_ADDRESS"
