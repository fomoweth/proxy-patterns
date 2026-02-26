// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  IERC173
/// @notice Standard interface for contract ownership.
interface IERC173 {
    /// @notice Emitted when ownership is transferred from `previousOwner` to `newOwner`.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Returns the current owner.
    function owner() external view returns (address);

    /// @notice Transfers ownership of the contract to a new account.
    /// @param  newOwner The address of the new owner.
    function transferOwnership(address newOwner) external payable;
}
