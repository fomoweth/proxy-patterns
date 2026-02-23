// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Utils} from "../ERC1967Utils.sol";
import {ERC1967Proxy} from "../ERC1967Proxy.sol";
import {ProxyAdmin} from "./ProxyAdmin.sol";

/// @title TransparentUpgradeableProxy
contract TransparentUpgradeableProxy is ERC1967Proxy {
    /// @notice Thrown when proxy admin attempts to access implementation functions.
    error ProxyDeniedAdminAccess();

    uint256 private immutable _admin;

    constructor(address implementation, address initialOwner, bytes memory data)
        payable
        ERC1967Proxy(implementation, data)
    {
        _admin = uint256(uint160(address(new ProxyAdmin(initialOwner))));
        ERC1967Utils.changeAdmin(_proxyAdmin());
    }

    /// @notice Returns the admin of this proxy.
    function _proxyAdmin() internal view virtual returns (address) {
        return address(uint160(_admin));
    }

    function _dispatchUpgradeToAndCall() private {
        address implementation;
        bytes memory data;

        assembly ("memory-safe") {
            // upgradeToAndCall(address,bytes) calldata structure:
            // 0x00-0x03: function selector (0x4f1ef286)	(4 bytes)
            // 0x04-0x23: implementation address			(32 bytes)
            // 0x24-0x43: offset to bytes data (0x40)		(32 bytes)
            // 0x44-0x63: length of bytes data				(32 bytes)
            // 0x64+	: bytes initialization data			(variable length)

            if iszero(eq(shr(0xe0, calldataload(0x00)), 0x4f1ef286)) {
                mstore(0x00, 0xd2b576ec) // ProxyDeniedAdminAccess()
                revert(0x1c, 0x04)
            }

            implementation := shr(0x60, shl(0x60, calldataload(0x04)))

            data := mload(0x40)
            let offset := add(data, 0x20)
            let length := calldataload(0x44)

            mstore(data, length)
            calldatacopy(offset, 0x64, length)
            mstore(0x40, add(offset, and(add(length, 0x1f), not(0x1f))))
        }

        ERC1967Utils.upgradeToAndCall(implementation, data);
    }

    /// @dev If `msg.sender` is the admin process the call internally,
    ///      otherwise transparently fallback to the proxy behavior.
    function _fallback() internal virtual override {
        if (msg.sender == _proxyAdmin()) {
            _dispatchUpgradeToAndCall();
        } else {
            super._fallback();
        }
    }
}
