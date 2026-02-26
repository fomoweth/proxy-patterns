// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Proxy} from "src/Proxy.sol";
import {ERC1967Utils} from "../ERC1967Utils.sol";

/// @title BeaconProxy
contract BeaconProxy is Proxy {
    uint256 private immutable _beacon;

    constructor(address beacon, bytes memory data) payable {
        ERC1967Utils.upgradeBeaconToAndCall(beacon, data);
        _beacon = uint256(uint160(beacon));
    }

    /// @notice Returns the beacon.
    function _getBeacon() internal view virtual returns (address) {
        return address(uint160(_beacon));
    }

    /// @notice Returns the current implementation of the associated beacon.
    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getBeaconImplementation(_getBeacon());
    }
}

