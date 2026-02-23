// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ERC1967Utils
/// @notice Library for reading and writing ERC-1967 storage slots and emitting corresponding events for upgradeable proxies.
/// @author fomoweth
library ERC1967Utils {
    /// @notice Thrown when the provided implementation address is invalid.
    error InvalidImplementation();

    /// @notice Thrown when the provided admin address is invalid.
    error InvalidAdmin();

    /// @notice Thrown when the provided beacon address is invalid.
    error InvalidBeacon();

    /// @notice Thrown when Ether is sent to an upgrade with no initialization call.
    error NonPayable();

    /// @notice Thrown when the returned UUID does not match expected ERC-1967 slot.
    error UnsupportedProxiableUUID(bytes32 slot);

    /// @notice Emitted when the ERC-1967 implementation slot is updated.
    event Upgraded(address indexed implementation);

    /// @notice Emitted when the ERC-1967 admin slot is updated.
    event AdminChanged(address previousAdmin, address newAdmin);

    /// @notice Emitted when the ERC-1967 beacon slot is updated.
    event BeaconUpgraded(address indexed beacon);

    /// @notice Precomputed event topic for {Upgraded}.
    /// @dev keccak256(bytes("Upgraded(address)"))
    bytes32 internal constant UPGRADED_EVENT_SIGNATURE =
        0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    /// @notice Precomputed event topic for {AdminChanged}.
    /// @dev keccak256(bytes("AdminChanged(address,address)"))
    bytes32 internal constant ADMIN_CHANGED_EVENT_SIGNATURE =
        0x7e644d79422f17c01e4894b5f4f588d331ebfa28653d42ae832dc59e38c9798f;

    /// @notice Precomputed event topic for {BeaconUpgraded}.
    /// @dev keccak256(bytes("BeaconUpgraded(address)"))
    bytes32 internal constant BEACON_UPGRADED_EVENT_SIGNATURE =
        0x1cf3b03a6cf19fa2baba4df148e9dcabedea7f8a5c07840e207e5c089be95d3e;

    /// @notice ERC-1967 storage slot for the implementation address.
    /// @dev bytes32(uint256(keccak256(bytes("eip1967.proxy.implementation"))) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice ERC-1967 storage slot for the admin address.
    /// @dev bytes32(uint256(keccak256(bytes("eip1967.proxy.admin"))) - 1)
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /// @notice ERC-1967 storage slot for the beacon address.
    /// @dev bytes32(uint256(keccak256(bytes("eip1967.proxy.beacon"))) - 1)
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /// @notice Returns the current implementation stored in the ERC-1967 implementation slot.
    /// @return implementation The address of the implementation contract.
    function getImplementation() internal view returns (address implementation) {
        assembly ("memory-safe") {
            implementation := sload(IMPLEMENTATION_SLOT)
        }
    }

    /// @notice Upgrades the proxy implementation and optionally executes an initialization call.
    /// @dev Reverts with {InvalidImplementation} if `implementation` has no deployed code.
    ///      Emits {Upgraded} with `implementation`.
    /// @param implementation The address of the new implementation contract.
    /// @param data ABI-encoded initializer calldata, or empty to skip the execution.
    function upgradeToAndCall(address implementation, bytes memory data) internal {
        assembly ("memory-safe") {
            implementation := shr(0x60, shl(0x60, implementation))

            if iszero(extcodesize(implementation)) {
                mstore(0x00, 0x68155f9a) // InvalidImplementation()
                revert(0x1c, 0x04)
            }

            sstore(IMPLEMENTATION_SLOT, implementation)
            log2(codesize(), 0x00, UPGRADED_EVENT_SIGNATURE, implementation)
        }

        _executeInitialization(implementation, data);
    }

    /// @notice Upgrades the proxy implementation via the UUPS pattern with proxiable UUID validation.
    /// @dev Reverts with {InvalidImplementation} if `proxiableUUID()` call fails or does not return 32 bytes.
    ///      Reverts with {UnsupportedProxiableUUID} if returned UUID is not {IMPLEMENTATION_SLOT}.
    ///      Emits {Upgraded} with `implementation`.
    /// @param implementation The address of the new UUPS-compliant implementation contract.
    /// @param data ABI-encoded initializer calldata, or empty to skip the execution.
    function upgradeToAndCallUUPS(address implementation, bytes memory data) internal {
        assembly ("memory-safe") {
            implementation := shr(0x60, shl(0x60, implementation))

            mstore(0x00, 0x52d1902d) // proxiableUUID()

            if iszero(and(eq(returndatasize(), 0x20), staticcall(gas(), implementation, 0x1c, 0x04, 0x20, 0x20))) {
                mstore(0x00, 0x68155f9a) // InvalidImplementation()
                revert(0x1c, 0x04)
            }

            if iszero(eq(mload(0x20), IMPLEMENTATION_SLOT)) {
                mstore(0x00, 0x3878d626) // UnsupportedProxiableUUID(bytes32)
                revert(0x1c, 0x24)
            }

            sstore(IMPLEMENTATION_SLOT, implementation)
            log2(codesize(), 0x00, UPGRADED_EVENT_SIGNATURE, implementation)
        }

        _executeInitialization(implementation, data);
    }

    /// @notice Returns the current admin stored in the ERC-1967 admin slot.
    /// @return admin The address of the proxy admin.
    function getAdmin() internal view returns (address admin) {
        assembly ("memory-safe") {
            admin := sload(ADMIN_SLOT)
        }
    }

    /// @notice Updates the proxy admin to a new address.
    /// @dev Reverts with {InvalidAdmin} if `admin` is the zero address.
    ///      Emits {AdminChanged} with previous admin and new admin.
    /// @param admin The address of the new proxy admin.
    function changeAdmin(address admin) internal {
        assembly ("memory-safe") {
            if iszero(shl(0x60, admin)) {
                mstore(0x00, 0xb5eba9f0) // InvalidAdmin()
                revert(0x1c, 0x04)
            }

            admin := shr(0x60, shl(0x60, admin))

            mstore(0x00, sload(ADMIN_SLOT))
            mstore(0x20, admin)
            sstore(ADMIN_SLOT, admin)
            log1(0x00, 0x40, ADMIN_CHANGED_EVENT_SIGNATURE)
        }
    }

    /// @notice Returns the current beacon stored in the ERC-1967 beacon slot.
    /// @return beacon The address of the beacon contract.
    function getBeacon() internal view returns (address beacon) {
        assembly ("memory-safe") {
            beacon := sload(BEACON_SLOT)
        }
    }

    /// @notice Returns the current implementation resolved by beacon via `implementation()`.
    /// @dev Reverts with {InvalidBeacon} if the call fails or does not return 32 bytes.
    /// @param beacon The address of the beacon contract to query.
    /// @return implementation The address of the implementation returned by the `beacon.implementation()`.
    function getBeaconImplementation(address beacon) internal view returns (address implementation) {
        assembly ("memory-safe") {
            mstore(0x00, 0x5c60da1b) // implementation()

            if iszero(and(eq(returndatasize(), 0x20), staticcall(gas(), beacon, 0x1c, 0x04, 0x00, 0x20))) {
                mstore(0x00, 0x30740e75) // InvalidBeacon()
                revert(0x1c, 0x04)
            }

            implementation := mload(0x00)
        }
    }

    /// @notice Upgrades the beacon and optionally executes an initialization call on its implementation.
    /// @dev Reverts with {InvalidBeacon} if `implementation()` call fails or returned implementation has no deployed code.
    ///      Emits {BeaconUpgraded} with `beacon`.
    /// @param beacon The address of the new beacon contract.
    /// @param data ABI-encoded initializer calldata, or empty to skip the execution.
    function upgradeBeaconToAndCall(address beacon, bytes memory data) internal {
        assembly ("memory-safe") {
            beacon := shr(0x60, shl(0x60, beacon))

            mstore(0x00, returndatasize())
            mstore(0x01, 0x5c60da1b) // implementation()

            if iszero(extcodesize(mload(staticcall(gas(), beacon, 0x1d, 0x04, 0x01, 0x20)))) {
                mstore(0x01, 0x30740e75) // InvalidBeacon()
                revert(0x1d, 0x04)
            }

            sstore(BEACON_SLOT, beacon)
            log2(codesize(), 0x00, BEACON_UPGRADED_EVENT_SIGNATURE, beacon)
        }

        _executeInitialization(getBeaconImplementation(beacon), data);
    }

    /// @notice Executes initialization on `implementation` with `data` if provided; otherwise validates that no Ether was sent.
    /// @dev Reverts with {NonPayable} if `data` is empty and `msg.value` is nonzero.
    /// @param implementation The address of the target for the initialization delegatecall.
    /// @param data ABI-encoded initializer calldata, or empty to skip the execution.
    function _executeInitialization(address implementation, bytes memory data) private {
        assembly ("memory-safe") {
            switch mload(data)
            case 0x00 {
                if callvalue() {
                    mstore(0x00, 0x6fb1b0e9) // NonPayable()
                    revert(0x1c, 0x04)
                }
            }
            default {
                if iszero(delegatecall(gas(), implementation, add(data, 0x20), mload(data), codesize(), 0x00)) {
                    let ptr := mload(0x40)
                    returndatacopy(ptr, 0x00, returndatasize())
                    revert(ptr, returndatasize())
                }
            }
        }
    }
}
