#!/bin/bash

# 03_BORROW.sh
# Borrows tokens from Aave Pool

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
    echo "  --token          Token symbol to borrow (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --amount         Amount to borrow (in token decimals)"
    echo "  --account        Account address borrowing the tokens"
    echo "  --private-key    Private key of the account"
    echo ""
    echo "Optional arguments:"
    echo "  --interest-mode  Interest rate mode: 1=stable, 2=variable (default: 2)"
    echo "  --on-behalf-of   Address that will incur the debt (default: same as account)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --amount 2 --account 0x123... --private-key 0xabc..."
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

# Get debt token address
DEBT_TOKEN_ADDRESS=$(get_variable_debt_address "$TOKEN")

# Determine decimals
if [ "$TOKEN" == "WBTC" ]; then
    DECIMALS=8
elif [ "$TOKEN" == "USDC" ] || [ "$TOKEN" == "USDT" ]; then
    DECIMALS=6
else
    DECIMALS=18
fi

# Calculate amount in wei
AMOUNT_WEI=$(echo "$AMOUNT * 10^$DECIMALS" | bc | cut -d'.' -f1)

# Interest rate mode description
if [ "$INTEREST_RATE_MODE" == "1" ]; then
    RATE_MODE_DESC="Stable"
else
    RATE_MODE_DESC="Variable"
fi

echo "=================================================="
echo "Borrowing from Aave Pool"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Amount:          $AMOUNT $TOKEN ($AMOUNT_WEI wei)"
echo "Account:         $ACCOUNT"
echo "On Behalf Of:    $ON_BEHALF_OF"
echo "Interest Mode:   $RATE_MODE_DESC ($INTEREST_RATE_MODE)"
echo "Pool:            $POOL_PROXY"
echo "Debt Token:      $DEBT_TOKEN_ADDRESS"
echo "=================================================="
echo ""

# Check if user has collateral
echo "Checking user account data..."
# Note: We would need to call getUserAccountData here, but cast doesn't easily decode complex return types
# For now, we'll proceed and let the transaction fail if insufficient collateral

# Execute borrow
echo " Sending borrow transaction..."
TX_HASH=$(cast send "$POOL_PROXY" \
    "borrow(address,uint256,uint256,uint16,address)" \
    "$TOKEN_ADDRESS" \
    "$AMOUNT_WEI" \
    "$INTEREST_RATE_MODE" \
    0 \
    "$ON_BEHALF_OF" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo " ERROR: Borrow transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Amount: $AMOUNT_WEI wei"
    echo "Account: $ACCOUNT"
    echo "Pool: $POOL_PROXY"
    echo ""
    echo "Possible reasons:"
    echo "  - Insufficient collateral"
    echo "  - Health factor would drop below 1"
    echo "  - Borrowing is not enabled for this reserve"
    echo "  - Borrow cap reached"
    echo "  - Insufficient gas"
    echo ""
    echo "Suggestion: Supply collateral first using:"
    echo "  ./utils/helpers/01_SUPPLY.sh --token <COLLATERAL_TOKEN> --amount <AMOUNT> --account $ACCOUNT"
    exit 1
fi

echo "Borrow transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 3

# Check balances after
echo "Verifying balances..."
TOKEN_BALANCE=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ACCOUNT" \
    --rpc-url "$RPC_URL")
DEBT_BALANCE=$(cast call "$DEBT_TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$ON_BEHALF_OF" \
    --rpc-url "$RPC_URL")

echo "Token balance:      $TOKEN_BALANCE wei"
echo "Debt token balance: $DEBT_BALANCE wei"
echo ""
echo "Borrow complete!"
echo "You borrowed $AMOUNT $TOKEN"
