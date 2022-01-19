# TWAM • [![tests](https://github.com/abigger87/twam/actions/workflows/tests.yml/badge.svg)](https://github.com/abigger87/twam/actions/workflows/tests.yml) [![lints](https://github.com/abigger87/twam/actions/workflows/lints.yml/badge.svg)](https://github.com/abigger87/twam/actions/workflows/lints.yml) ![GitHub](https://img.shields.io/github/license/abigger87/twam) ![GitHub package.json version](https://img.shields.io/github/package-json/v/abigger87/twam)

##### _Time Weighted Asset Mints_

A minting harness enabling time-weighted assets to determine minting prices.

## How it works

Requirements: `maxMintingAmount` number of erc721 tokens are minted to the `TWAM` contract in advance.

For a given mint's `allocationPeriod` (let's use 24 hours), a given type of asset can be deposited into the [twam](./src/TWAM.sol) contract. Note: during the `allocationPeriod`, the deposit token can be withdrawn.

Once the `allocationPeriod` ends, a cooldown period begins with a length of `mintingStart` - `allocationEnd`.

Note: the cooldown may be 0.

At the beginning of the minting period `mintingStart`, each erc721 can be minted at the price equal to (total allocated assets) / (maximum supply erc721 tokens) as long as it exceeds the `minimumPrice`.

If the `minimumPrice` is not reached, minting is prohibited, and nothing happens during the minting period.

If all tokens are minted at the end of the minting period, the session is completed.

Otherwise (when the `minimumPrice` isn't met or not all tokens are minted), one of three options are available:
1. The TWAM process starts over again.
2. Minting is enabled at the max{`resultPrice`, `minimumPrice`}.
3. The session is ended.

This option is denoted as the session's `rolloverOption`.

## Blueprint

```ml
lib
├─ ds-test — https://github.com/dapphub/ds-test
├─ forge-std — https://github.com/brockelmore/forge-std
├─ solmate — https://github.com/Rari-Capital/solmate
src
├─ tests
│  └─ TWAM.t — "TWAM Tests"
└─ TWAM — "Time Weighted Asset Mint Contract"
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
# OR #
yarn test
```

## License

[AGPL-3.0-only](https://github.com/abigger87/twam/blob/master/LICENSE)

# Acknowledgements

- [foundry](https://github.com/gakonst/foundry)
- [solmate](https://github.com/Rari-Capital/solmate)
- [forge-std](https://github.com/brockelmore/forge-std)
- [foundry-toolchain](https://github.com/onbjerg/foundry-toolchain) by [onbjerg](https://github.com/onbjerg).
- [forge-starter](https://github.com/abigger87/forge-starter) by [abigger87](https://github.com/abigger87).
- [forge-template](https://github.com/FrankieIsLost/forge-template) by [FrankieIsLost](https://github.com/FrankieIsLost).
- [Georgios Konstantopoulos](https://github.com/gakonst) for [forge-template](https://github.com/gakonst/forge-template) resource.

## Disclaimer

_These smart contracts are being provided as is. No guarantee, representation or warranty is being made, express or implied, as to the safety or correctness of the user interface or the smart contracts. They have not been audited and as such there can be no assurance they will work as intended, and users may experience delays, failures, errors, omissions, loss of transmitted information or loss of funds. The creators are not liable for any of the foregoing. Users should proceed with caution and use at their own risk._
