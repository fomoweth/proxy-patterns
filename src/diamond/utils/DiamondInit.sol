// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {LibDiamond} from "../LibDiamond.sol";

/// @title 	DiamondInit
/// @notice Initializes state variables and/or do other actions when the {IDiamondCut.diamondCut} function is called.
contract DiamondInit {
    function init() external payable {
        mapping(bytes4 => bool) storage supportedInterfaces = LibDiamond.diamondStorage().supportedInterfaces;
        supportedInterfaces[type(IERC165).interfaceId] = true;
        supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}
