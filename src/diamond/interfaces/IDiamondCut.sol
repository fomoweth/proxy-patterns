// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  IDiamondCut
/// @notice Defines the standard for adding, replacing, and removing facet functions.
interface IDiamondCut {
    /// @notice Emitted when facet cuts are applied.
    event DiamondCut(FacetCut[] cuts, address init, bytes data);

    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /// @notice Modifies (add/replace/remove) any number of functions and optionally executes a function call via `delegatecall`.
    /// @param cuts The array of {FacetCut} structs.
    /// @param init The address to forward calldata (address(0) to skip).
    /// @param data The calldata to execute.
    function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata data) external;
}
