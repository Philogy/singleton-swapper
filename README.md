# Singleton Swapper

"Singleton Swapper" is a Singleton AMM, whereby liquidity pools all live under the same address. The pools use
a simple constant-product formula ($k = x\cdot y$). This repo serves as a proof-of-concept to see
how low the gas costs of a singleton AMM can be pushed and to experiment with an in-memory flash
accounting design.

## How it Works

### Internal Flash Accounting

Whenever operations are conducted within the pool such as providing liquidity or multi-hop swaps, all
balance changes are first tracked internally, in memory, allowing users to only settle final
net-changes at the end of an operations block.

Balance changes are tracked using a hash-map that lives in memory. The hash-map can have any size
and is dictated by the caller when initiating a batch of operations. A small hash-map will save gas as
it won't have to allocate as much memory upfront but it will increase the probability of collisions
between token keys making some reads / writes more expensive. Transactions can be simulated
off-chain to determine the best hash-map size.

### Program

Interacting with pools is done via the `execute(bytes program)` function. The `program` is
a serialized list of operations, with the following structure:
```
  <2 bytes> accounting hash map size (in tokens) e.g. 0x0040 => up to 64 key, value pairs
            in the accounting map

  [for every operation]:
    <1 byte>  8-bit operation
    <n bytes> opcode data
```

This non-ABI encoding ensures that you can have a custom set of operations with each operation
taking on a different amount of data while keeping calldata size minimal.

### Operations

Each 8-bit operation specifier consists of `<4-bits operation id><4-bits flags>`. So there can be up
to 16 top-level operations which each being to interpret 4 added flags.
Parameters are always tightly packed. You can see how to encode individual ops in the
[`EncoderLib`](src/utils/EncoderLib.sol).

Note: The name of the ops are given from the perspective from the pool e.g. "send" means that from
the perspective of the pool it's sending assets to some external recipient.

**`SWAP (0x00)`**

Descrition: Performs a swap in pool of `token0`-`token1` (must be sorted order `token0 < token1`)

  - flags:
    - 0: whether swapping token0 for token1 (`1`: token0 => token1, `0`: token1 => token0)
  - params:
    - `address token0`
    - `address token1`
    - `uint128 amount`

**`ADD_LIQ (0x10)`**

Descrition: Adds liquidity to the pool `token0`-`token1` (must be sorted order `token0 < token1`).
Uses amounts `maxAmount0` and `maxAmount1`. If liquidity is already present may not use the entirety
of one amount as it will match the current ratio. The `to` address will be credited the liquidity
position.

  - flags: None
  - params:
    - `address token0`
    - `address token1`
    - `address to`
    - `uint128 maxAmount0`
    - `uint128 maxAmount1`

**`RM_LIQ (0x20)`**

Descrition: Remove liquidity from the pool `token0`-`token1` (must be sorted order `token0
< token1`). Withdraws `liquidity` from the caller's position in the specified pool. Will revert if
caller doesn't have at least `liquidity` in their position.

  - flags: None
  - params:
    - `address token0`
    - `address token1`
    - `uint256 liquidity`

**`SEND (0x30)`**

Descrition: Sends `amount` of `token` to recipient `to`.

  - flags: None
  - params:
    - `address token`
    - `address to`
    - `uint128 amount`

**`RECEIVE (0x40)`**

Descrition: Calls the [`give`](src/interfaces/IGiver.sol#6) callback on the `caller` with `token`
and `amount` as parameters. Will then check for and credit any received amount of `token` in the
internal accounting. Note that sent `token` not yet accounted for will also be accounted as
"received" in the callback.

  - flags: None
  - params:
    - `address token`
    - `uint128 amount`

**`SWAP_HEAD (0x50)`**

Descrition: Similar to `SWAP` except that the "out token" will be stored internally as `lastToken`
for use in `SWAP_HOP`.

  - flags:
    - 0: whether swapping token0 for token1 (`1`: token0 => token1, `0`: token1 => token0)
  - params:
    - `address token0`
    - `address token1`
    - `uint128 amount`

**`SWAP_HOP (0x60)`**

Descrition: Will look at `lastToken` set by the last `SWAP_HEAD` or `SWAP_HOP` operation and swap
the internally accounted out amount of `lastToken` for `nextToken`. Reverts if internal `lastToken`
delta is positive i.e. the pool contract is owed tokens. Sets `lastToken` to `nextToken`.

  - params:
    - `address nextToken`
