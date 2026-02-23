// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  Initializable
/// @notice Versioned initializable mixin for upgradeable contracts.
/// @author fomoweth
abstract contract Initializable {
    /// @notice Thrown when initialization is attempted in an invalid state.
    error InvalidInitialization();

    /// @notice Thrown when a function restricted to the initialization phase is called outside initialization.
    error NotInitializing();

    /// @notice Emitted when the contract is initialized to `version`.
    event Initialized(uint64 version);

    /// @notice Precomputed event topic for {Initialized}.
    ///	@dev    keccak256(bytes("Initialized(uint64)"))
    bytes32 private constant INITIALIZED_EVENT_SIGNATURE =
        0xc7f505b2f371ae2175ee4913f4499e1f2633a7b5936321eed1cdaeb6115181d2;

    /// @notice Storage slot for the initialization state (initializing flag + initialized version).
    /// @dev    bytes32(~uint256(uint32(bytes4(keccak256("INITIALIZATION_SLOT")))))
    bytes32 private constant INITIALIZATION_SLOT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff865973bc;

    /// @notice Maximum initializable version number.
    /// @dev    Sentinel value used by {_disableInitializers} to permanently lock initialization.
    uint64 private constant MAX_VERSION = (1 << 64) - 1;

    /// @notice Restricts an initializer function to be invoked at most once (version 1).
    /// @dev    Reverts with {InvalidInitialization} if the contract is already initialized
    ///         (except for permitted construction context).
    modifier initializer() {
        bool isTopLevelCall;
        assembly ("memory-safe") {
            let state := sload(INITIALIZATION_SLOT)
            if state {
                if iszero(lt(extcodesize(address()), eq(shr(0x01, state), 0x01))) {
                    mstore(0x00, 0xf92ee8a9) // InvalidInitialization()
                    revert(0x1c, 0x04)
                }
            }
            isTopLevelCall := iszero(and(state, 0x01))
            sstore(INITIALIZATION_SLOT, 0x03)
        }
        _;
        assembly ("memory-safe") {
            if isTopLevelCall {
                sstore(INITIALIZATION_SLOT, 0x02)
                mstore(0x20, 0x01)
                log1(0x20, 0x20, INITIALIZED_EVENT_SIGNATURE)
            }
        }
    }

    /// @notice Restricts a reinitializer function to be invoked with `version` at most once.
    /// @dev    Reverts with {InvalidInitialization} if called during initialization phase
    ///         or if `version` is not greater than current version.
    modifier reinitializer(uint64 version) {
        assembly ("memory-safe") {
            version := shl(0x01, and(version, MAX_VERSION))
            let state := sload(INITIALIZATION_SLOT)
            if iszero(lt(and(state, 0x01), lt(state, version))) {
                mstore(0x00, 0xf92ee8a9) // InvalidInitialization()
                revert(0x1c, 0x04)
            }
            sstore(INITIALIZATION_SLOT, or(0x01, version))
        }
        _;
        assembly ("memory-safe") {
            sstore(INITIALIZATION_SLOT, version)
            mstore(0x20, shr(0x01, version))
            log1(0x20, 0x20, INITIALIZED_EVENT_SIGNATURE)
        }
    }

    /// @notice Restricts a function to be callable only during an initialization phase.
    /// @dev    Functions with this modifier may only be invoked within the dynamic call
    ///         tree of a function guarded by {initializer} or {reinitializer}.
    modifier onlyInitializing() {
        _checkInitializing();
        _;
    }

    /// @notice Checks if the contract is currently initializing.
    /// @dev    Reverts with {NotInitializing} when the initializing flag is not set.
    function _checkInitializing() internal view virtual {
        assembly ("memory-safe") {
            if iszero(and(0x01, sload(INITIALIZATION_SLOT))) {
                mstore(0x00, 0xd7e6bcf8) // NotInitializing()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Permanently locks the contract, preventing any future initialization or reinitialization.
    /// @dev    Sets the initialized version to {MAX_VERSION} and emits {Initialized} with {MAX_VERSION}.
    ///         Reverts with {InvalidInitialization} if called while initializing.
    function _disableInitializers() internal virtual {
        assembly ("memory-safe") {
            let state := sload(INITIALIZATION_SLOT)
            if and(state, 0x01) {
                mstore(0x00, 0xf92ee8a9) // InvalidInitialization()
                revert(0x1c, 0x04)
            }
            if iszero(eq(shr(0x01, state), MAX_VERSION)) {
                sstore(INITIALIZATION_SLOT, shl(0x01, MAX_VERSION))
                mstore(0x20, MAX_VERSION)
                log1(0x20, 0x20, INITIALIZED_EVENT_SIGNATURE)
            }
        }
    }

    /// @notice Returns the highest version that has been initialized.
    /// @return version The initialized version.
    function _getInitializedVersion() internal view virtual returns (uint64 version) {
        assembly ("memory-safe") {
            version := shr(0x01, sload(INITIALIZATION_SLOT))
        }
    }

    /// @notice Returns whether the contract is currently initializing.
    /// @return flag True if the initializing flag is set, false otherwise.
    function _isInitializing() internal view virtual returns (bool flag) {
        assembly ("memory-safe") {
            flag := and(0x01, sload(INITIALIZATION_SLOT))
        }
    }
}
