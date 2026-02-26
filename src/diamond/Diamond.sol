// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Proxy} from "src/Proxy.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {LibDiamond} from "./LibDiamond.sol";

/// @title Diamond
contract Diamond is Proxy {
    constructor(address initialOwner, IDiamondCut.FacetCut[] memory cuts, address init, bytes memory data) {
        LibDiamond.setContractOwner(initialOwner);
        LibDiamond.diamondCut(cuts, init, data);
    }

    function _implementation() internal view virtual override returns (address facet) {
        if ((facet = LibDiamond.getFacetBySelector(msg.sig)) == address(0)) {
            revert LibDiamond.FunctionNotExists(msg.sig);
        }
    }

    receive() external payable virtual override {}
}
