#!/bin/bash

# 00_CONFIGURE_FAUCET.sh
# Configures the Faucet contract to allow minting of testnet tokens

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/../helpers/load_addresses.sh"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

if [ -z "$RPC_URL" ] || [ -z "$DEPLOYER_PRIVATE_KEY" ]; then
    echo "ERROR: RPC_URL and DEPLOYER_PRIVATE_KEY must be set in .env"
    exit 1
fi

echo "=================================================="
echo "🔧 Configuring Faucet for Token Minting"
echo "=================================================="
echo "Faucet: $FAUCET"
echo "=================================================="
echo ""

TOKENS=("WETH" "DAI" "USDC" "USDT" "WBTC" "LINK" "AAVE" "EURS")

for TOKEN in "${TOKENS[@]}"; do
    TOKEN_ADDRESS=$(get_token_address "$TOKEN")

    if [ -z "$TOKEN_ADDRESS" ]; then
        echo "Skipping $TOKEN (not found)"
        continue
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Enabling minting for $TOKEN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Token Address: $TOKEN_ADDRESS"

    IS_MINTABLE=$(cast call "$FAUCET" \
        "isMintable(address)(bool)" \
        "$TOKEN_ADDRESS" \
        --rpc-url "$RPC_URL")

    if [ "$IS_MINTABLE" == "true" ]; then
        echo "Already mintable"
        echo ""
        continue
    fi

    echo "Setting mintable to true..."
    TX_HASH=$(cast send "$FAUCET" \
        "setMintable(address,bool)" \
        "$TOKEN_ADDRESS" \
        "true" \
        --rpc-url "$RPC_URL" \
        --private-key "$DEPLOYER_PRIVATE_KEY" \
        --json | jq -r '.transactionHash')

    if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
        echo " Failed to enable minting for $TOKEN"
        echo ""
        continue
    fi

    echo "Enabled! TX: $TX_HASH"
    echo ""
    sleep 1
done

echo "=================================================="
echo "Faucet Configuration Complete!"
echo "=================================================="
echo ""
echo "All tokens are now mintable via the Faucet."
echo "You can now run:"
echo "  ./utils/scripts/00_SETUP_ACCOUNTS.sh"
echo "  ./utils/scripts/01_SCENARIO_WETH_SUPPLY.sh"
echo ""
