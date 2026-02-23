// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "src/utils/Ownable.sol";

/// @title  ProxyAdmin
/// @notice Auxiliary contract responsible for upgrading {TransparentUpgradeableProxy} instance.
contract ProxyAdmin is Ownable {
    /// @notice The version of the upgrade interface of the contract.
    /// @dev    If this getter is missing, both `upgrade(address,address)` and `upgradeAndCall(address,address,bytes)`
    ///         are present, and `upgrade` must be used if no function should be called, while `upgradeAndCall` will
    ///         invoke the `receive` function if the third argument is the empty byte string.
    ///         If the getter returns `"5.0.0"`, only `upgradeAndCall(address,address,bytes)` is present, and the
    ///         third argument must be the empty byte string if no function should be called, making it impossible to
    ///         invoke the `receive` function during an upgrade.
    string public constant UPGRADE_INTERFACE_VERSION = "5.0.0";

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    /// @notice Upgrades the proxy to the new implementation, and optionally executes initialization calldata.
    /// @param  proxy The address of the proxy instance to upgrade.
    /// @param  implementation The address of the new implementation to set in the proxy.
    /// @param  data ABI-encoded initializer calldata, or empty to skip execution.
    function upgradeAndCall(address proxy, address implementation, bytes calldata data)
        public
        payable
        virtual
        onlyOwner
    {
        assembly ("memory-safe") {
            let ptr := mload(0x40)
            mstore(ptr, 0x4f1ef286) // upgradeToAndCall(address,bytes)
            mstore(add(ptr, 0x20), shr(0x60, shl(0x60, implementation)))
            mstore(add(ptr, 0x40), 0x40)
            mstore(add(ptr, 0x60), data.length)
            calldatacopy(add(ptr, 0x80), data.offset, data.length)

            let callSize := add(0x64, and(add(data.length, 0x1f), not(0x1f)))
            mstore(0x40, add(ptr, callSize))

            if iszero(call(gas(), proxy, callvalue(), add(ptr, 0x1c), callSize, codesize(), 0x00)) {
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }
}
