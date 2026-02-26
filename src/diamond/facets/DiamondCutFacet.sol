// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../LibDiamond.sol";

/// @title 	DiamondCutFacet
/// @notice Owner-gated facet that executes diamond cuts.
contract DiamondCutFacet is IDiamondCut {
    /// @inheritdoc IDiamondCut
    function diamondCut(FacetCut[] calldata cuts, address init, bytes calldata data) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(cuts, init, data);
    }
}
