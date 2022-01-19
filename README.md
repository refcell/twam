# Time Weighted Asset Mints • [![tests](https://github.com/abigger87/twam/actions/workflows/tests.yml/badge.svg)](https://github.com/abigger87/twam/actions/workflows/tests.yml) [![lints](https://github.com/abigger87/twam/actions/workflows/lints.yml/badge.svg)](https://github.com/abigger87/twam/actions/workflows/lints.yml) ![GitHub](https://img.shields.io/github/license/abigger87/twam) ![GitHub package.json version](https://img.shields.io/github/package-json/v/abigger87/twam)

A minting harness enabling time-weighted assets to determine minting prices.

## How it works

For a given mint's `allocationPeriod` (let's use 24 hours), a given type of asset can be deposited into the [twam](./src/TWAM.sol) contract.

Once the `allocationPeriod` ends, each erc721 can be minted at the price equal to (total allocated assets) / (maximum supply erc721 tokens).

When the `allocationPeriod` ends, the `permissionedPeriod` begins where users who deposited can mint their tokens at the price, or withdraw.

If not all tokens are minted at the end of the `permissondPeriod`, either the process starts over again or minting is enabled at the resulting price.

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
