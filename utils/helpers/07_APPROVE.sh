#!/bin/bash

# 07_APPROVE.sh
# Approves token spending for Aave Pool contract

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

# Default values
AMOUNT="115792089237316195423570985008687907853269984665640564039457584007913129639935" # max uint256

# Usage function
usage() {
    echo "Usage: $0 --token <TOKEN> --spender <SPENDER_ADDRESS> --account <ACCOUNT_ADDRESS> --private-key <PRIVATE_KEY> [--amount <AMOUNT>]"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --spender        Address to approve (usually Pool contract)"
    echo "  --account        Account address that owns the tokens"
    echo "  --private-key    Private key of the account"
    echo ""
    echo "Optional arguments:"
    echo "  --amount         Amount to approve (default: max uint256)"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --spender \$POOL_PROXY --account 0x123... --private-key 0xabc..."
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --spender)
            SPENDER="$2"
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
        --amount)
            AMOUNT="$2"
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
if [ -z "$TOKEN" ] || [ -z "$SPENDER" ] || [ -z "$ACCOUNT" ] || [ -z "$PRIVATE_KEY" ]; then
    echo " ERROR: Missing required arguments"
    usage
fi

# Validate RPC_URL
if [ -z "$RPC_URL" ]; then
    echo " ERROR: RPC_URL not set. Please set it in .env file or pass via --rpc-url"
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
echo "Approving Token Spending"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Spender:         $SPENDER"
echo "Account:         $ACCOUNT"
echo "Amount:          $AMOUNT"
echo "=================================================="
echo ""

# Execute approval
echo " Sending approval transaction..."
TX_HASH=$(cast send "$TOKEN_ADDRESS" \
    "approve(address,uint256)" \
    "$SPENDER" \
    "$AMOUNT" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo "ERROR: Approval transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Spender: $SPENDER"
    echo "Account: $ACCOUNT"
    echo ""
    echo "Possible reasons:"
    echo "  - Insufficient gas"
    echo "  - Invalid addresses"
    echo "  - Network connectivity issues"
    exit 1
fi

echo "Approval successful!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Verify approval
echo "Verifying approval..."
ALLOWANCE=$(cast call "$TOKEN_ADDRESS" \
    "allowance(address,address)(uint256)" \
    "$ACCOUNT" \
    "$SPENDER" \
    --rpc-url "$RPC_URL")

echo "Current Allowance: $ALLOWANCE"
echo ""
echo "Token approval complete!"
