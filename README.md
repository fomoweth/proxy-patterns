# Proxy Patterns

A comprehensive reference implementation of major EVM proxy patterns with unified test specifications.

## Patterns

| Pattern               | EIP                     | Key Mechanism                                                    |
| --------------------- | ----------------------- | ---------------------------------------------------------------- |
| **Transparent Proxy** | `EIP-1967`              | Admin-gated fallback routing via `msg.sender` check              |
| **UUPS**              | `EIP-1822` + `EIP-1967` | Upgrade logic in implementation; immutable `__self` guard        |
| **Beacon Proxy**      | `EIP-1967`              | Fleet of proxies reading `implementation` from a shared `beacon` |
| **Clones**            | `EIP-1167`              | 45-byte delegating bytecode via `CREATE` / `CREATE2`             |

## Project Structure

```

proxy-patterns/
├── src/
│   ├── clone/
│   │   └──	Clones.sol
│   ├── ERC1967/
│   │   ├──	beacon/
│   │   │  	├── BeaconProxy.sol
│   │   │  	└── UpgradeableBeacon.sol
│   │   ├──	transparent/
│   │   │  	├── ProxyAdmin.sol
│   │   │  	└── TransparentUpgradeableProxy.sol
│   │   ├──	uups/
│   │   │  	├── UUPSProxy.sol
│   │   │  	└── UUPSUpgradeable.sol
│   │   ├──	ERC1967Proxy.sol
│   │   └──	ERC1967Utils.sol
│   ├── diamond/
│   │   │   faces/
│   │   │   ├── DiamondCutFacet.sol
│   │   │   ├── DiamondLoupeFacet.sol
│   │   │   └── OwnershipFacet.sol
│   │   ├── interfaces/
│   │   │       ├── IDiamondCut.sol
│   │   │       ├── IDiamondLoupe.sol
│   │   │       └── IERC173.sol
│   │   ├── Diamond.sol
│   │   └── LibDiamond.sol
│   ├── utils/
│   ├── Initializable.sol
│   └── Ownable.sol
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
