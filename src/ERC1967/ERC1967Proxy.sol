// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Proxy} from "src/Proxy.sol";
import {ERC1967Utils} from "./ERC1967Utils.sol";

/// @title  ERC1967Proxy
/// @notice Minimal upgradeable proxy that delegates calls to an implementation stored in the ERC-1967 implementation slot.
/// @author fomoweth
contract ERC1967Proxy is Proxy {
    /// @notice Thrown when the proxy is left uninitialized.
    error ProxyUninitialized();

    /// @notice Initializes the proxy with an implementation and optional initializer calldata.
    /// @param  implementation The address of the initial implementation contract.
    /// @param  data ABI-encoded initializer calldata, or empty to skip initialization when permitted.
    constructor(address implementation, bytes memory data) payable {
        if (!_unsafeAllowUninitialized() && data.length == 0) revert ProxyUninitialized();
        ERC1967Utils.upgradeToAndCall(implementation, data);
    }

    /// @notice Returns the current implementation used for delegation.
    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @notice Returns whether the proxy can be left uninitialized.
    function _unsafeAllowUninitialized() internal pure virtual returns (bool) {}
}
