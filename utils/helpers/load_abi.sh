#!/bin/bash

# load_abi.sh
# Extracts ABI from deployment JSON files for use with cast

set -e

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOYMENTS_DIR="$PROJECT_ROOT/deployments/sepolia"

# Function to get ABI from deployment file
# Usage: get_abi "ContractName"
get_abi() {
    local contract_name=$1
    local json_file="$DEPLOYMENTS_DIR/${contract_name}.json"

    if [ ! -f "$json_file" ]; then
        echo " ERROR: Deployment file not found: $json_file" >&2
        return 1
    fi

    if command -v jq &> /dev/null; then
        jq -c '.abi' "$json_file"
    else
        echo " ERROR: jq is required for ABI extraction. Please install jq." >&2
        return 1
    fi
}

# Export commonly used ABIs as environment variables
export POOL_ABI=$(get_abi "Pool-Implementation")
export ERC20_ABI=$(get_abi "WETH-TestnetMintableERC20-Aave")
export ATOKEN_ABI=$(get_abi "AToken-Aave")
export DEBT_TOKEN_ABI=$(get_abi "VariableDebtToken-Aave")
export ORACLE_ABI=$(get_abi "WETH-TestnetPriceAggregator-Aave")
export POOL_DATA_PROVIDER_ABI=$(get_abi "PoolDataProvider-Aave")

# Export function for other scripts to use
export -f get_abi
