// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC173} from "../interfaces/IERC173.sol";
import {LibDiamond} from "../LibDiamond.sol";

/// @title 	OwnershipFacet
/// @notice ERC-173 ownership for the Diamond
contract OwnershipFacet is IERC173 {
    /// @inheritdoc IERC173
    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }

    /// @inheritdoc IERC173
    function transferOwnership(address newOwner) external payable {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(newOwner);
    }
}
