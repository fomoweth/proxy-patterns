// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  IERC165
/// @notice Interface of the ERC-165 standard, as defined in the https://eips.ethereum.org/EIPS/eip-165
interface IERC165 {
    /// @notice Queries if this contract implements the interface defined by `interfaceId`.
    /// @param interfaceId The interface identifier
    /// @return `true` if the contract implements `interfaceId` and `interfaceId` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
