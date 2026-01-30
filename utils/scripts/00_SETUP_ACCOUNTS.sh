#!/bin/bash

# 00_SETUP_ACCOUNTS.sh
# Funds test accounts with ETH from deployer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

if [ -z "$RPC_URL" ]; then
    echo " ERROR: RPC_URL not set in .env file"
    exit 1
fi

DEPLOYER_ADDRESS="0x67c1BD4630e1361A6F366bB2909920e29BE91547"

declare -a ACCOUNTS=(
    "0x20A43DbBDfd90ad4488D44693662e1d01EAa3A37"
    "0x25e82A0b41c153fdB1b4e7fbA5Eb84B55DdD9406"
    "0x04F7DFe1D37927aF036fCC1f4a2a2FAd3E9dEa5E"
    "0xAaBC76c120A3d435df5769728de43439fd6e16f2"
    "0x9eFe8259f16377579Ad4C28e944f06c9376E2b7F"
)

AMOUNT="100000000000000000"

echo "=================================================="
echo "Setting Up Test Accounts"
echo "=================================================="
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Amount per account: 0.5 ETH"
echo "Number of accounts: ${#ACCOUNTS[@]}"
echo "=================================================="
echo ""

echo "Checking deployer balance..."
DEPLOYER_BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$RPC_URL")
DEPLOYER_BALANCE_ETH=$(echo "scale=6; $DEPLOYER_BALANCE / 10^18" | bc)
echo "Deployer balance: $DEPLOYER_BALANCE_ETH ETH"
echo ""

TOTAL_NEEDED=$(echo "${#ACCOUNTS[@]} * 0.5" | bc)
if (( $(echo "$DEPLOYER_BALANCE_ETH < $TOTAL_NEEDED" | bc -l) )); then
    echo "Needed: ~$TOTAL_NEEDED ETH (plus gas)"
fi

echo ""

for i in "${!ACCOUNTS[@]}"; do
    ACCOUNT="${ACCOUNTS[$i]}"
    ACCOUNT_NUM=$((i))

    echo "─────────────────────────────────────────────────"
    echo "Account $ACCOUNT_NUM: $ACCOUNT"
    echo "─────────────────────────────────────────────────"

    CURRENT_BALANCE=$(cast balance "$ACCOUNT" --rpc-url "$RPC_URL")
    CURRENT_ETH=$(echo "scale=6; $CURRENT_BALANCE / 10^18" | bc)
    echo "Current balance: $CURRENT_ETH ETH"

    echo "Sending 0.1 ETH..."
    TX_HASH=$(cast send "$ACCOUNT" \
        --value "$AMOUNT" \
        --rpc-url "$RPC_URL" \
        --private-key "$DEPLOYER_PRIVATE_KEY" \
        --json | jq -r '.transactionHash')

    if [ -z "$TX_HASH" ] || [ "$TX_HASH" == "null" ]; then
        echo " ERROR: Failed to send ETH to Account $ACCOUNT_NUM"
        echo "Account: $ACCOUNT"
        continue
    fi

    echo "Transaction sent: $TX_HASH"

    sleep 2

    NEW_BALANCE=$(cast balance "$ACCOUNT" --rpc-url "$RPC_URL")
    NEW_ETH=$(echo "scale=6; $NEW_BALANCE / 10^18" | bc)
    echo "New balance: $NEW_ETH ETH"
    echo ""
done

echo "=================================================="
echo "Account Setup Complete!"
echo "=================================================="
echo ""
echo "Account Summary:"
echo "  Account 0 (WETH Supply):      ${ACCOUNTS[0]}"
echo "  Account 1 (USDT Supply/Borrow): ${ACCOUNTS[1]}"
echo "  Account 2 (USDC Max Borrow):   ${ACCOUNTS[2]}"
echo "  Account 3 (WBTC Supply/Withdraw): ${ACCOUNTS[3]}"
echo "  Account 4 (Liquidator):        ${ACCOUNTS[4]}"
echo ""
echo "All accounts funded with 0.5 ETH each"
