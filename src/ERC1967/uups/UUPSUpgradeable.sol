// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Utils} from "../ERC1967Utils.sol";

/// @title  UUPSUpgradeable
/// @notice Abstract contract provides upgradeability mechanism designed for UUPS (Universal Upgradeable Proxy Standard) proxies.
abstract contract UUPSUpgradeable {
    /// @notice Thrown when the call is from an unauthorized context.
    error UnauthorizedCallContext();

    /// @notice The original address of this contract
    uint256 private immutable __self = uint256(uint160(address(this)));

    /// @notice The version of the upgrade interface of the contract.
    /// @dev    If this getter is missing, both `upgrade(address,address)` and `upgradeAndCall(address,address,bytes)`
    ///         are present, and `upgrade` must be used if no function should be called, while `upgradeAndCall` will
    ///         invoke the `receive` function if the third argument is the empty byte string.
    ///         If the getter returns `"5.0.0"`, only `upgradeAndCall(address,address,bytes)` is present, and the
    ///         third argument must be the empty byte string if no function should be called, making it impossible to
    ///         invoke the `receive` function during an upgrade.
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    /// @notice Ensures that the execution is being performed through a delegatecall.
    modifier onlyProxy() {
        _checkProxy();
        _;
    }

    /// @notice Ensures that the execution is not being performed through a delegatecall.
    modifier notDelegated() {
        _checkNotDelegated();
        _;
    }

    /// @notice Returns the storage slot used by the implementation.
    function proxiableUUID() public view virtual notDelegated returns (bytes32) {
        return ERC1967Utils.IMPLEMENTATION_SLOT;
    }

    function upgradeToAndCall(address implementation, bytes calldata data) public payable virtual onlyProxy {
        _authorizeUpgrade(implementation);
        ERC1967Utils.upgradeToAndCallUUPS(implementation, data);
    }

    /// @notice Reverts if the execution is not performed via delegatecall.
    function _checkProxy() internal view virtual {
        uint256 self = __self;
        assembly ("memory-safe") {
            if eq(self, address()) {
                mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Reverts if the execution is performed via delegatecall.
    function _checkNotDelegated() internal view virtual {
        uint256 self = __self;
        assembly ("memory-safe") {
            if iszero(eq(self, address())) {
                mstore(0x00, 0x9f03a026) // UnauthorizedCallContext()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Ensures `msg.sender` is authorized to upgrade the proxy to `newImplementation`.
    /// @dev    Called by {upgradeToAndCall}.
    function _authorizeUpgrade(address newImplementation) internal virtual;
}
