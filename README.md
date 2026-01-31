# PointsHook (Uniswap v4 Hook)

This repo contains a simple Uniswap v4 hook, `PointsHook`, that mints **ERC-1155 “points”** to users when they interact with a specific **ETH/TOKEN** pool.

## What it does

- **After swap points**: When a user swaps **ETH -> TOKEN** in the target pool, the hook mints points to the user.
- **After add liquidity points**: When a user adds liquidity to the target pool, the hook mints points based on the ETH side of the add.
- **Referral points (optional)**: If a referral address is provided, the hook can mint a small bonus to the referral address.

Points are minted as **ERC-1155 tokens**, where the token id is the **pool id** (`PoolId`) for the pool where the action happened.

## Target pool (ETH/TOKEN)

This hook is intended for an ETH/TOKEN pool where:

- `currency0` is **native ETH** (`address(0)`)
- `currency1` is the configured `TOKEN` set in the constructor

The hook checks this `PoolKey` before awarding points.

## `hookData` format (user + referral)

In Uniswap v4 callbacks, the `sender` is often a router/periphery contract rather than the end user.
So this hook expects the “real user” (and optional referral) to be passed via `hookData`:

- `hookData = abi.encode(user, referral)`
- `referral` may be `address(0)` to mean “no referral”
- self-referrals (`user == referral`) are ignored

## Point rates (current)

Rates are currently hard-coded in `src/PointsHook.sol`:

- **Swap**: `points = ethSpendAmount / 5`
- **Referral bonus (swap)**: `referralPoints = ethSpendAmount / 20` (5% of `ethSpendAmount`)
- **Add liquidity**: `points = ethAmount / 4`

> Note: A common alternative is to make referralPoints a % of the *user’s points* (points units),
> rather than a % of `ethSpendAmount` (wei).

## Build

This project uses Foundry.

```bash
forge build
```

## Notes

- This hook mints ERC-1155 tokens using Solmate’s `ERC1155`.
- The `uri()` function is a placeholder.

