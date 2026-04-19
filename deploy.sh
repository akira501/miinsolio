#!/bin/bash
set -e 

# Usage: deploy.sh [network]
# Default to local network if not provided
NETWORK=${1:-local}

echo "Deploying to network: $NETWORK"

if [ "$NETWORK" = "local" ]; then
    # Ensure local replica is running
    echo "Starting local replica in background..."
    dfx start --background || echo "Replica might already be running"
fi

# Install dependencies just to be sure
pnpm install --prefer-offline

# Ensure mops dependencies are updated
cd src/backend && mops install && cd ../../

# Generate Declarations
dfx generate backend

if [ "$NETWORK" = "local" ]; then
    echo "Deploying Internet Identity..."
    dfx deploy internet_identity --network local
fi

# Build frontend explicitly before uploading to asset canister
pnpm build

# Deploy canisters
dfx deploy --network $NETWORK

echo "Deployment to $NETWORK finished successfully!"

if [ "$NETWORK" = "local" ]; then
    echo "Local replica is still running in background. You can stop it with 'dfx stop'."
fi