#!/bin/bash

# 10_ENABLE_BORROWING.sh
# Enables borrowing for a specific reserve

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
    echo "Usage: $0 --token <TOKEN> --private-key <PRIVATE_KEY>"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --private-key    Private key of the pool admin"
    echo ""
    echo "Optional arguments:"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --private-key 0xabc..."
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --private-key)
            PRIVATE_KEY="$2"
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
if [ -z "$TOKEN" ] || [ -z "$PRIVATE_KEY" ]; then
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

# Get PoolConfigurator address
POOL_CONFIGURATOR=$(get_address "PoolConfigurator-Proxy-Aave")
if [ -z "$POOL_CONFIGURATOR" ]; then
    echo "ERROR: PoolConfigurator address not found in deployed-contracts.json"
    exit 1
fi

echo "=================================================="
echo "Enabling Borrowing for Reserve"
echo "=================================================="
echo "Token:              $TOKEN"
echo "Token Address:      $TOKEN_ADDRESS"
echo "PoolConfigurator:   $POOL_CONFIGURATOR"
echo "=================================================="
echo ""

# Enable borrowing
echo "Sending transaction to enable borrowing..."
TX_HASH=$(cast send "$POOL_CONFIGURATOR" \
    "setReserveBorrowing(address,bool)" \
    "$TOKEN_ADDRESS" \
    true \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo "ERROR: Transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo ""
    echo "Possible reasons:"
    echo "  - Not authorized (must be pool admin)"
    echo "  - Invalid token address"
    echo "  - Network connectivity issues"
    exit 1
fi

echo "Transaction successful!"
echo "Transaction Hash: $TX_HASH"
echo ""

echo "=================================================="
echo "Borrowing enabled for $TOKEN!"
echo "=================================================="
