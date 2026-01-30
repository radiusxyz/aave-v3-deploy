#!/bin/bash

# load_addresses.sh
# Loads deployed contract addresses from deployments/sepolia/*.json files

set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOYMENTS_DIR="$PROJECT_ROOT/deployments/sepolia"

# Check if deployments directory exists
if [ ! -d "$DEPLOYMENTS_DIR" ]; then
    echo " ERROR: Deployments directory not found at $DEPLOYMENTS_DIR"
    echo "Have you deployed the contracts yet?"
    exit 1
fi

# Function to load a contract address
# Usage: load_address "ContractName"
load_address() {
    local contract_name=$1
    local json_file="$DEPLOYMENTS_DIR/${contract_name}.json"

    if [ ! -f "$json_file" ]; then
        echo " ERROR: Deployment file not found: $json_file"
        return 1
    fi

    # Extract address using jq or grep/sed fallback
    if command -v jq &> /dev/null; then
        jq -r '.address' "$json_file"
    else
        grep -o '"address"[[:space:]]*:[[:space:]]*"[^"]*"' "$json_file" | sed 's/.*"\([^"]*\)".*/\1/'
    fi
}

# Load all important contract addresses
export POOL_PROXY=$(load_address "Pool-Proxy-Aave")
export POOL_DATA_PROVIDER=$(load_address "PoolDataProvider-Aave")
export ACL_MANAGER=$(load_address "ACLManager-Aave")
export POOL_CONFIGURATOR=$(load_address "PoolConfigurator-Proxy-Aave")
export ORACLE=$(load_address "AaveOracle-Aave")
export POOL_ADDRESSES_PROVIDER=$(load_address "PoolAddressesProvider-Aave")
export FAUCET=$(load_address "Faucet-Aave")

# Load token addresses
export WETH_TOKEN=$(load_address "WETH-TestnetMintableERC20-Aave")
export DAI_TOKEN=$(load_address "DAI-TestnetMintableERC20-Aave")
export USDC_TOKEN=$(load_address "USDC-TestnetMintableERC20-Aave")
export USDT_TOKEN=$(load_address "USDT-TestnetMintableERC20-Aave")
export WBTC_TOKEN=$(load_address "WBTC-TestnetMintableERC20-Aave")
export LINK_TOKEN=$(load_address "LINK-TestnetMintableERC20-Aave")
export AAVE_TOKEN=$(load_address "AAVE-TestnetMintableERC20-Aave")
export EURS_TOKEN=$(load_address "EURS-TestnetMintableERC20-Aave")

# Load aToken addresses
export WETH_ATOKEN=$(load_address "WETH-AToken-Aave")
export DAI_ATOKEN=$(load_address "DAI-AToken-Aave")
export USDC_ATOKEN=$(load_address "USDC-AToken-Aave")
export USDT_ATOKEN=$(load_address "USDT-AToken-Aave")
export WBTC_ATOKEN=$(load_address "WBTC-AToken-Aave")
export LINK_ATOKEN=$(load_address "LINK-AToken-Aave")
export AAVE_ATOKEN=$(load_address "AAVE-AToken-Aave")
export EURS_ATOKEN=$(load_address "EURS-AToken-Aave")

# Load variable debt token addresses
export WETH_VARIABLE_DEBT=$(load_address "WETH-VariableDebtToken-Aave")
export DAI_VARIABLE_DEBT=$(load_address "DAI-VariableDebtToken-Aave")
export USDC_VARIABLE_DEBT=$(load_address "USDC-VariableDebtToken-Aave")
export USDT_VARIABLE_DEBT=$(load_address "USDT-VariableDebtToken-Aave")
export WBTC_VARIABLE_DEBT=$(load_address "WBTC-VariableDebtToken-Aave")
export LINK_VARIABLE_DEBT=$(load_address "LINK-VariableDebtToken-Aave")
export AAVE_VARIABLE_DEBT=$(load_address "AAVE-VariableDebtToken-Aave")
export EURS_VARIABLE_DEBT=$(load_address "EURS-VariableDebtToken-Aave")

# Load stable debt token addresses
export WETH_STABLE_DEBT=$(load_address "WETH-StableDebtToken-Aave")
export DAI_STABLE_DEBT=$(load_address "DAI-StableDebtToken-Aave")
export USDC_STABLE_DEBT=$(load_address "USDC-StableDebtToken-Aave")
export USDT_STABLE_DEBT=$(load_address "USDT-StableDebtToken-Aave")
export WBTC_STABLE_DEBT=$(load_address "WBTC-StableDebtToken-Aave")
export LINK_STABLE_DEBT=$(load_address "LINK-StableDebtToken-Aave")
export AAVE_STABLE_DEBT=$(load_address "AAVE-StableDebtToken-Aave")
export EURS_STABLE_DEBT=$(load_address "EURS-StableDebtToken-Aave")

# Load oracle addresses
export WETH_ORACLE=$(load_address "WETH-TestnetPriceAggregator-Aave")
export DAI_ORACLE=$(load_address "DAI-TestnetPriceAggregator-Aave")
export USDC_ORACLE=$(load_address "USDC-TestnetPriceAggregator-Aave")
export USDT_ORACLE=$(load_address "USDT-TestnetPriceAggregator-Aave")
export WBTC_ORACLE=$(load_address "WBTC-TestnetPriceAggregator-Aave")
export LINK_ORACLE=$(load_address "LINK-TestnetPriceAggregator-Aave")
export AAVE_ORACLE=$(load_address "AAVE-TestnetPriceAggregator-Aave")
export EURS_ORACLE=$(load_address "EURS-TestnetPriceAggregator-Aave")

# Function to get token address by symbol
get_token_address() {
    local token=$1
    case $token in
        WETH) echo "$WETH_TOKEN" ;;
        DAI) echo "$DAI_TOKEN" ;;
        USDC) echo "$USDC_TOKEN" ;;
        USDT) echo "$USDT_TOKEN" ;;
        WBTC) echo "$WBTC_TOKEN" ;;
        LINK) echo "$LINK_TOKEN" ;;
        AAVE) echo "$AAVE_TOKEN" ;;
        EURS) echo "$EURS_TOKEN" ;;
        *) echo ""; return 1 ;;
    esac
}

# Function to get aToken address by symbol
get_atoken_address() {
    local token=$1
    case $token in
        WETH) echo "$WETH_ATOKEN" ;;
        DAI) echo "$DAI_ATOKEN" ;;
        USDC) echo "$USDC_ATOKEN" ;;
        USDT) echo "$USDT_ATOKEN" ;;
        WBTC) echo "$WBTC_ATOKEN" ;;
        LINK) echo "$LINK_ATOKEN" ;;
        AAVE) echo "$AAVE_ATOKEN" ;;
        EURS) echo "$EURS_ATOKEN" ;;
        *) echo ""; return 1 ;;
    esac
}

# Function to get variable debt token address by symbol
get_variable_debt_address() {
    local token=$1
    case $token in
        WETH) echo "$WETH_VARIABLE_DEBT" ;;
        DAI) echo "$DAI_VARIABLE_DEBT" ;;
        USDC) echo "$USDC_VARIABLE_DEBT" ;;
        USDT) echo "$USDT_VARIABLE_DEBT" ;;
        WBTC) echo "$WBTC_VARIABLE_DEBT" ;;
        LINK) echo "$LINK_VARIABLE_DEBT" ;;
        AAVE) echo "$AAVE_VARIABLE_DEBT" ;;
        EURS) echo "$EURS_VARIABLE_DEBT" ;;
        *) echo ""; return 1 ;;
    esac
}

# Function to get stable debt token address by symbol
get_stable_debt_address() {
    local token=$1
    case $token in
        WETH) echo "$WETH_STABLE_DEBT" ;;
        DAI) echo "$DAI_STABLE_DEBT" ;;
        USDC) echo "$USDC_STABLE_DEBT" ;;
        USDT) echo "$USDT_STABLE_DEBT" ;;
        WBTC) echo "$WBTC_STABLE_DEBT" ;;
        LINK) echo "$LINK_STABLE_DEBT" ;;
        AAVE) echo "$AAVE_STABLE_DEBT" ;;
        EURS) echo "$EURS_STABLE_DEBT" ;;
        *) echo ""; return 1 ;;
    esac
}

# Function to get oracle address by symbol
get_oracle_address() {
    local token=$1
    case $token in
        WETH) echo "$WETH_ORACLE" ;;
        DAI) echo "$DAI_ORACLE" ;;
        USDC) echo "$USDC_ORACLE" ;;
        USDT) echo "$USDT_ORACLE" ;;
        WBTC) echo "$WBTC_ORACLE" ;;
        LINK) echo "$LINK_ORACLE" ;;
        AAVE) echo "$AAVE_ORACLE" ;;
        EURS) echo "$EURS_ORACLE" ;;
        *) echo ""; return 1 ;;
    esac
}

# Generic function to get any contract address by deployment name
get_address() {
    local contract_name=$1
    load_address "$contract_name"
}

# Export functions so they can be used by other scripts
export -f get_address
export -f load_address
export -f get_token_address
export -f get_atoken_address
export -f get_variable_debt_address
export -f get_stable_debt_address
export -f get_oracle_address
