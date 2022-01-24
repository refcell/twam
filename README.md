# TWAM • [![tests](https://github.com/abigger87/twam/actions/workflows/tests.yml/badge.svg)](https://github.com/abigger87/twam/actions/workflows/tests.yml) [![lints](https://github.com/abigger87/twam/actions/workflows/lints.yml/badge.svg)](https://github.com/abigger87/twam/actions/workflows/lints.yml) ![GitHub](https://img.shields.io/github/license/abigger87/twam) ![GitHub package.json version](https://img.shields.io/github/package-json/v/abigger87/twam)

##### _Time Weighted Asset Mints_

A minting harness enabling time-weighted assets to determine minting prices.

## How it works

[TwamFactory](./src/TwamFactory.sol) manages creating TWAM Sessions.

A given TWAM Session can be created permissionlessly. With two requirements:
- The session creator sets the TwamFactory ERC721 token balance to at least `maxMiningAmount`.
- The session creator then transfers 1 ERC721 token to the TwamFactory to verify they are the owner of the ERC721 Tokens.

The singular ERC721 Token transfer is required to trigger the [TwamFactory](./src/TwamFactory.sol)'s `onERC721Received` hook that sets the approved session creator.

This comes with assumptions:
- The creator owns all ERC721 Tokens to start with before doing a sale (or they risk another owner frontrunning the session creation).
- ERC721 Tokens [0-maxMintingAmount] are owned by the TwamFactory since sales are done sequentially.

When a TWAM Session is created using the [TwamFactory](./src/TwamFactory.sol)'s `createTwam` function, a minimal proxy contract is created using the arguments as immutables (h/t [ZeframLou](https://github.com/ZeframLou/clones-with-immutable-args)).

#### TWAM Session Parameters

`token` - The address of the ERC721 Contract.
`coordinator` - The sale profit receiver.
`allocationStart` - The timestamp when the allocation period begins.
`allocationEnd` - The timestamp when the allocation period ends.
`mintingStart` - The timestamp when the minting period begins.
`mintingEnd` - The timestamp when the minting period ends.
`minPrice` - The minimum price per ERC721 token.
`depositToken` - The address of the ERC20 token that is paid by users.
`maxMintingAmount` - The maximum number of ERC721 Tokens available for sale.
`rolloverOption` - Option in {1, 2, 3} indicating what happens when a Session ends.


#### TWAM Session Lifecycle

For a given mint's `allocationPeriod` (let's use 24 hours), a given type of asset can be deposited into the [twam](./src/TWAM.sol) contract. Note: during the `allocationPeriod`, the deposit token **cannot** be withdrawn.

Additionally, a loss penalty is calculated with respect to when you deposit in the allocation period. The later you deposit, the more of a penalty you will occur if you choose to forgo minting. This prevents spoofing allocations, helping those who are genuinely interested in minting the ERC721 token.

NOTE: if someones total deposits in a session aren't enough to mint at least one ERC721 token based on price, withdrawals are allowed **without** a penalty.


Once the `allocationPeriod` ends, a cooldown period begins with a length of `mintingStart` - `allocationEnd`. At this time, no more deposits are permitted.

Note: there may be no cooldown if `mintingStart` = `allocationEnd`.

At the beginning of the minting period `mintingStart`, each ERC721 can be minted at the price equal to (total allocated assets) / (maximum supply ERC721 tokens) as long as it exceeds the `minPrice` TWAM session parameter.

If the `minPrice` is not reached, minting is prohibited, and nothing happens during the minting period.

If all tokens are minted at the end of the minting period, the session is completed.

Otherwise (when the `minimumPrice` isn't met or not all tokens are minted), one of three options are available based on the Session's `rolloverOption`:
1. The TWAM Session starts over again.
2. Minting is enabled at the max{`resultPrice`, `minimumPrice`}.
3. The session is ended.

The Session's `rolloverOption` may only be one of these three.


#### Minter Functions

`deposit(uint256)` - Deposits a `uint256` amount into the Session during the allocation period.
`withdraw(uint256)` - Allows a user to withdraw after the Session ends (`mintingEnd` is passed) and the `rolloverOption` is 3.
`mint(uint256)` - Mints a number of ERC721 tokens to a user during the minting period as calculated by `uint256` / `resultPrice` where `resultPrice` is the final price per ERC721 token.
`forgo(uint256)` - Allows a user to withdraw their deposited token, giving up their minting allocation. This may incur a loss penalty as a function of when the deposits are made.


#### Coordinator Functions

`rollover()` - Allows the coordinator to rollover the Session if the minting is over - only sets the `rolloverOffset` if the `rolloverOption` is one of {1,2}.
`withdrawRewards()` - Withdraws the deposit tokens earned by the coordinator in exchange for the minted ERC721 Tokens.

## Blueprint

```ml
lib
├─ clones-with-immutable-args — https://github.com/ZeframLou/clones-with-immutable-args
├─ ds-test — https://github.com/dapphub/ds-test
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solmate — https://github.com/Rari-Capital/solmate
src
├─ tests
│  ├─ TwamBase.t — "Primary TWAM Functionality Tests"
│  └─ TwamFactory.t — "Proxy and TwamBase Deployment Tests"
├─ TwamBase — "Time Weighted Asset Mint Logic Contract"
└─ TwamFactory — "Minimal Proxy Deployer"
```

## Development

### Install DappTools

Install DappTools using their [installation guide](https://github.com/dapphub/dapptools#installation).

### First time with Forge/Foundry?

Don't have [rust](https://www.rust-lang.org/tools/install) installed?
Run
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then, install [foundry](https://github.com/gakonst/foundry) with:
```bash
cargo install --git https://github.com/gakonst/foundry --bin forge --locked
```

### Setup and Build

```bash
make
```

### Run Tests

```bash
make test
```

## License

[AGPL-3.0-only](https://github.com/abigger87/twam/blob/master/LICENSE)

# Acknowledgements

- [foundry](https://github.com/gakonst/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [clones-with-immutable-args](https://github.com/ZeframLou/clones-with-immutable-args)
- [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg).
- [forge-starter](https://github.com/abigger87/forge-starter) by [abigger87](https://github.com/abigger87).
- [forge-template](https://github.com/FrankieIsLost/forge-template) by [FrankieIsLost](https://github.com/FrankieIsLost).
- [Georgios Konstantopoulos](https://github.com/gakonst) for [forge-template](https://github.com/gakonst/forge-template) resource.

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
