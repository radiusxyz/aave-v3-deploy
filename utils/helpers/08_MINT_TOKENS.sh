#!/bin/bash

# 08_MINT_TOKENS.sh
# Mints testnet tokens to a recipient

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
    echo "Usage: $0 --token <TOKEN> --amount <AMOUNT> --recipient <RECIPIENT_ADDRESS> --private-key <PRIVATE_KEY>"
    echo ""
    echo "Required arguments:"
    echo "  --token          Token symbol to mint (WETH, DAI, USDC, USDT, WBTC, LINK, AAVE, EURS)"
    echo "  --amount         Amount to mint (in token decimals)"
    echo "  --recipient      Address to receive the minted tokens"
    echo "  --private-key    Private key of an account with minting rights (deployer)"
    echo ""
    echo "Optional arguments:"
    echo "  --rpc-url        RPC URL (default: from .env RPC_URL)"
    echo ""
    echo "Example:"
    echo "  $0 --token WETH --amount 100 --recipient 0x123... --private-key 0xabc..."
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
        --recipient)
            RECIPIENT="$2"
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
            echo " ERROR: Unknown argument: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$TOKEN" ] || [ -z "$AMOUNT" ] || [ -z "$RECIPIENT" ] || [ -z "$PRIVATE_KEY" ]; then
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
AMOUNT_WEI=$(echo "$AMOUNT * 10^$DECIMALS" | bc | cut -d'.' -f1)

echo "=================================================="
echo "🪙  Minting Testnet Tokens via Faucet"
echo "=================================================="
echo "Token:           $TOKEN"
echo "Token Address:   $TOKEN_ADDRESS"
echo "Amount:          $AMOUNT $TOKEN ($AMOUNT_WEI wei)"
echo "Recipient:       $RECIPIENT"
echo "Faucet:          $FAUCET"
echo "=================================================="
echo ""

# Check balance before
echo "Checking balance before minting..."
BALANCE_BEFORE=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$RECIPIENT" \
    --rpc-url "$RPC_URL")
echo "Balance before: $BALANCE_BEFORE wei"
echo ""

# Mint tokens via Faucet contract
echo " Minting tokens via Faucet..."
TX_HASH=$(cast send "$FAUCET" \
    "mint(address,address,uint256)" \
    "$TOKEN_ADDRESS" \
    "$RECIPIENT" \
    "$AMOUNT_WEI" \
    --rpc-url "$RPC_URL" \
    --private-key "$PRIVATE_KEY" \
    --json | jq -r '.transactionHash')

if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
    echo ""
    echo " ERROR: Mint transaction failed"
    echo "Token: $TOKEN ($TOKEN_ADDRESS)"
    echo "Amount: $AMOUNT_WEI wei"
    echo "Recipient: $RECIPIENT"
    echo "Faucet: $FAUCET"
    echo ""
    echo "Possible reasons:"
    echo "  - Private key does not have Faucet owner rights"
    echo "  - Faucet permissions not configured"
    echo "  - Token not mintable via Faucet"
    echo "  - Insufficient gas"
    echo ""
    echo "Note: Testnet tokens must be minted via the Faucet contract"
    exit 1
fi

echo "Mint transaction sent!"
echo "Transaction Hash: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 3

# Check balance after
echo "Checking balance after minting..."
BALANCE_AFTER=$(cast call "$TOKEN_ADDRESS" \
    "balanceOf(address)(uint256)" \
    "$RECIPIENT" \
    --rpc-url "$RPC_URL")
echo "Balance after: $BALANCE_AFTER wei"
echo ""
echo "Minting complete!"
echo "Minted $AMOUNT $TOKEN to $RECIPIENT"
