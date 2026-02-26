// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  IDiamondLoupe
/// @notice Provides introspection into the Diamond's facets and selectors.
interface IDiamondLoupe {
    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Returns all facet addresses and their function selectors.
    /// @return facets The array of {Facet} struct.
    function facets() external view returns (Facet[] memory facets);

    /// @notice Returns all function selectors supported by `facet`.
    /// @param facet The address of the facet to query.
    /// @return selectors The array of function selectors.
    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory selectors);

    /// @notice Returns all facet addresses used by the diamond.
    /// @return facetAddresses The array of facet addresses.
    function facetAddresses() external view returns (address[] memory facetAddresses);

    /// @notice Returns the address of the facet supports `selector`.
    /// @param selector The function selector to look up.
    /// @return facet The address of the facet.
    function facetAddress(bytes4 selector) external view returns (address facet);
}
