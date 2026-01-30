#!/bin/bash

# 11_SET_USE_AS_COLLATERAL.sh
# Enables or disables a reserve as collateral for a user

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
    echo "Usage: $0 --token <TOKEN> --account <ACCOUNT> --private-key <PRIVATE_KEY> [--enable true|false]"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --account        User account address"
    echo "  --private-key    Private key of the account"
    echo ""
    echo "Optional arguments:"
    echo "  --enable         Enable (true) or disable (false) as collateral (default: true)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token USDT --account 0x123... --private-key 0xabc... --enable true"
    exit 1
}

# Default value
ENABLE="true"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            TOKEN="$2"
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
        --enable)
            ENABLE="$2"
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
            echo "ERROR: Unknown argument: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$TOKEN" ] || [ -z "$ACCOUNT" ] || [ -z "$PRIVATE_KEY" ]; then
    echo "ERROR: Missing required arguments"
    usage
fi

# Validate RPC_URL
if [ -z "$RPC_URL" ]; then
    echo "ERROR: RPC_URL not set. Please set it in .env file or pass via --rpc-url"
    exit 1
fi

# Get token address
TOKEN_ADDRESS=$(get_token_address "$TOKEN")
if [ -z "$TOKEN_ADDRESS" ]; then
    echo "ERROR: Invalid token symbol: $TOKEN"
    echo "Valid tokens: WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS"
    exit 1
fi

echo "=================================================="
echo "Setting Use Reserve As Collateral"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Account:         $ACCOUNT"
echo "Enable:          $ENABLE"
echo "Pool:            $POOL_PROXY"
echo "=================================================="
echo ""

# Execute transaction
echo "Sending transaction..."
TX_HASH=$(cast send "$POOL_PROXY" \
    "setUserUseReserveAsCollateral(address,bool)" \
    "$TOKEN_ADDRESS" \
    "$ENABLE" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo "ERROR: Transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Account: $ACCOUNT"
    echo ""
    echo "Possible reasons:"
    echo "  - No balance in this reserve"
    echo "  - Reserve cannot be used as collateral"
    echo "  - Insufficient gas"
    exit 1
fi

echo "Transaction successful!"
echo "Transaction Hash: $TX_HASH"
echo ""

if [ "$ENABLE" == "true" ]; then
    echo "=================================================="
    echo "$TOKEN is now enabled as collateral for $ACCOUNT"
    echo "=================================================="
else
    echo "=================================================="
    echo "$TOKEN is now disabled as collateral for $ACCOUNT"
    echo "=================================================="
fi
