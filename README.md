# Proxy Patterns

A comprehensive reference implementation of major EVM proxy patterns with unified test specifications.

## Project Structure

```
proxy-patterns/
├── src/
├── test/
├── script/
└── foundry.toml
```

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
