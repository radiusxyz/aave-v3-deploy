#!/bin/bash

# 06_QUERY.sh
# Queries user balances and positions in Aave

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
    echo "Usage: $0 --account <ACCOUNT_ADDRESS> [--token <TOKEN>]"
    echo ""
    echo "Required arguments:"
    echo "  --account        Account address to query"
    echo ""
    echo "Optional arguments:"
    echo "  --token          Specific token to query (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "                   If not provided, queries all tokens"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --account 0x123..."
    echo "  $0 --account 0x123... --token WETH"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --account)
            ACCOUNT="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
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
if [ -z "$ACCOUNT" ]; then
    echo " ERROR: Missing required argument: --account"
    usage
fi

# Validate RPC_URL
if [ -z "$RPC_URL" ]; then
    echo " ERROR: RPC_URL not set. Please set it in .env file or pass via --rpc-url"
    exit 1
fi

# Function to convert wei to human readable with decimals
wei_to_human() {
    local wei=$1
    local decimals=$2
    local symbol=$3

    if [ "$wei" == "0" ]; then
        echo "0 $symbol"
        return
    fi

    # Use bc for division
    local human=$(echo "scale=6; $wei / 10^$decimals" | bc)
    echo "$human $symbol"
}

# Function to query a single token
query_token() {
    local token=$1
    local token_addr=$(get_token_address "$token")
    local atoken_addr=$(get_atoken_address "$token")
    local vdebt_addr=$(get_variable_debt_address "$token")
    local sdebt_addr=$(get_stable_debt_address "$token")

    # Determine decimals
    if [ "$token" == "WBTC" ]; then
        decimals=8
    elif [ "$token" == "USDC" ] || [ "$token" == "USDT" ]; then
        decimals=6
    else
        decimals=18
    fi

    # Get balances (strip scientific notation)
    local token_balance=$(cast call "$token_addr" "balanceOf(address)(uint256)" "$ACCOUNT" --rpc-url "$RPC_URL" | awk '{print $1}')
    local atoken_balance=$(cast call "$atoken_addr" "balanceOf(address)(uint256)" "$ACCOUNT" --rpc-url "$RPC_URL" | awk '{print $1}')
    local vdebt_balance=$(cast call "$vdebt_addr" "balanceOf(address)(uint256)" "$ACCOUNT" --rpc-url "$RPC_URL" | awk '{print $1}')
    local sdebt_balance=$(cast call "$sdebt_addr" "balanceOf(address)(uint256)" "$ACCOUNT" --rpc-url "$RPC_URL" | awk '{print $1}')

    # Convert to human readable
    local token_human=$(wei_to_human "$token_balance" "$decimals" "$token")
    local atoken_human=$(wei_to_human "$atoken_balance" "$decimals" "a$token")
    local vdebt_human=$(wei_to_human "$vdebt_balance" "$decimals" "$token")
    local sdebt_human=$(wei_to_human "$sdebt_balance" "$decimals" "$token")

    # Print results
    echo "  ┌─ $token ─────────────────────────────────"
    echo "  │ Wallet Balance:         $token_human"
    echo "  │ aToken Balance:         $atoken_human"
    echo "  │ Variable Debt:          $vdebt_human"
    echo "  │ Stable Debt:            $sdebt_human"
    echo "  └──────────────────────────────────────────"
    echo ""
}

echo "=================================================="
echo "Querying Aave Position"
echo "=================================================="
echo "Account: $ACCOUNT"
echo "=================================================="
echo ""

# Query ETH balance (strip scientific notation)
ETH_BALANCE=$(cast balance "$ACCOUNT" --rpc-url "$RPC_URL" | awk '{print $1}')
ETH_HUMAN=$(wei_to_human "$ETH_BALANCE" 18 "ETH")
echo "Native ETH Balance: $ETH_HUMAN"
echo ""

# If specific token requested
if [ -n "$TOKEN" ]; then
    echo "Token Balances:"
    echo ""
    query_token "$TOKEN"
else
    # Query all tokens
    echo "All Token Balances:"
    echo ""

    TOKENS=("WETH" "DAI" "USDC" "USDT" "WBTC" "LINK" "AAVE" "EURS")

    for token in "${TOKENS[@]}"; do
        query_token "$token"
    done
fi

echo "=================================================="
echo "Query complete!"
echo "=================================================="
