// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {LibDiamond} from "../LibDiamond.sol";

/// @title  DiamondLoupeFacet
/// @notice EIP-2535 introspection
contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return LibDiamond.diamondStorage().supportedInterfaces[interfaceId];
    }

    /// @inheritdoc IDiamondLoupe
    function facets() external view returns (Facet[] memory result) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        address[] memory addresses = ds.facetAddresses;
        uint256 length = addresses.length;

        result = new Facet[](length);
        for (uint256 i = 0; i < length;) {
            result[i] = Facet({facetAddress: addresses[i], functionSelectors: ds.facetToSelectors[addresses[i]]});

            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IDiamondLoupe
    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory) {
        return LibDiamond.diamondStorage().facetToSelectors[facet];
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddresses() external view returns (address[] memory) {
        return LibDiamond.diamondStorage().facetAddresses;
    }

    /// @inheritdoc IDiamondLoupe
    function facetAddress(bytes4 selector) external view returns (address) {
        return LibDiamond.getFacetBySelector(selector);
    }
}
