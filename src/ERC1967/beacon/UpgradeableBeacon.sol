// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "src/utils/Ownable.sol";

/// @title UpgradeableBeacon
contract UpgradeableBeacon is Ownable {
    /// @notice Thrown when the provided implementation address for the beacon is invalid.
    error InvalidBeaconImplementation();

    /// @notice Emitted when the implementation returned by the beacon is updated.
    event Upgraded(address indexed implementation);

    /// @notice Precomputed event topic for {Upgraded}.
    ///	@dev    keccak256(bytes("Upgraded(address)"))
    bytes32 private constant UPGRADED_EVENT_SIGNATURE =
        0xbc7cd75a20ee27fd9adebab32041f755214dbc6bffa90cc0225b39da2e5c2d3b;

    /// @notice Storage slot for the implementation address.
    /// @dev    uint72(bytes9(keccak256("UPGRADEABLE_BEACON_IMPLEMENTATION_SLOT")))
    uint256 private constant UPGRADEABLE_BEACON_IMPLEMENTATION_SLOT = 0x7adb300363fbbe04c9;

    constructor(address initialImplementation, address initialOwner) {
        _setImplementation(initialImplementation);
        _initializeOwner(initialOwner);
    }

    /// @notice Returns the current implementation.
    function implementation() public view virtual returns (address logic) {
        assembly ("memory-safe") {
            logic := sload(UPGRADEABLE_BEACON_IMPLEMENTATION_SLOT)
        }
    }

    /// @notice Upgrades the beacon to a new implementation.
    function upgradeTo(address newImplementation) public payable virtual onlyOwner {
        _setImplementation(newImplementation);
    }

    /// @notice Sets the implementation to `newImplementation` for this beacon.
    /// @dev    Reverts with {InvalidBeaconImplementation} if `newImplementation`
    ///         is not a deployed contract. Emits {Upgraded} with `newImplementation`.
    function _setImplementation(address newImplementation) private {
        assembly ("memory-safe") {
            newImplementation := shr(0x60, shl(0x60, newImplementation))

            if iszero(extcodesize(newImplementation)) {
                mstore(0x00, 0x7e5aeae6) // InvalidBeaconImplementation()
                revert(0x1c, 0x04)
            }

            sstore(UPGRADEABLE_BEACON_IMPLEMENTATION_SLOT, newImplementation)
            log2(codesize(), 0x00, UPGRADED_EVENT_SIGNATURE, newImplementation)
        }
    }
}
