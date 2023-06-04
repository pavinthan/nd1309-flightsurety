# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

### System Specification

For this project, I used:

```bash
Nodejs: v16.19.1
NPM: 8.19.3
Truffle v5.8.3
Ganache v7.8.0 (@ganache/cli: 0.9.0, @ganache/core: 0.9.0)
Solidity: ^0.8.16
openzeppelin-solidity: 4.6.0
```

### Dependencies

For this project, you will need to have:

1. **Node and NPM** installed - NPM is distributed with [Node.js](https://www.npmjs.com/get-npm)

```bash
# Check Node version
node -v
# Check NPM version
npm -v
```

2. **Truffle v5.X.X** - A development framework for Ethereum.

```bash
# Unsinstall any previous version
npm uninstall -g truffle
# Install
npm install -g truffle
# Specify a particular version
npm install -g truffle@5.0.2
# Verify the version
truffle version
```

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

## Develop Client

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder

## Resources

- [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
- [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
- [Truffle Framework](http://truffleframework.com/)
- [Ganache Local Blockchain](http://truffleframework.com/ganache/)
- [Remix Solidity IDE](https://remix.ethereum.org/)
- [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
- [Ethereum Blockchain Explorer](https://etherscan.io/)
- [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)
