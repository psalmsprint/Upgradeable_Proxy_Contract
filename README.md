# Proxy Contract

This repository contains a basic proxy contract implementation used to delegate calls to a separate implementation contract. The proxy holds the state, while the logic lives in the implementation.

## Overview

The proxy forwards external calls to an implementation address using delegation. This allows the logic to be upgraded without changing the proxy address that users interact with.

Key characteristics:
- State is stored in the proxy
- Logic is executed from the implementation
- Calls are forwarded through a fallback mechanism

## Architecture

- **Proxy**
  - Stores the implementation address
  - Stores administrative ownership
  - Delegates calls to the implementation
  - Emits upgrade events when the implementation changes

- **Implementation**
  - Contains the business logic
  - Assumes storage layout compatibility with the proxy

## Upgrade Flow

1. Proxy is deployed with an initial implementation address
2. Users interact only with the proxy
3. Owner updates the implementation address when an upgrade is required
4. Existing state remains intact

## Security Considerations

- Only the owner can upgrade the implementation
- Storage layout between proxy and implementation must remain consistent
- Delegate calls execute in the proxy’s context
- Initialization must be handled carefully to avoid takeover risks

## Usage Notes

- Always test upgrades in isolation before deployment
- Avoid adding state variables to the proxy unless necessary
