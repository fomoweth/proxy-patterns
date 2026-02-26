// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LibDiamond} from "../LibDiamond.sol";

/// @title DiamondMultiInit
contract DiamondMultiInit {
    error ArityLengthMismatch();

    function multiInit(address[] calldata targets, bytes[] calldata calls) external payable {
        if (targets.length != calls.length) revert ArityLengthMismatch();

        for (uint256 i; i < targets.length;) {
            LibDiamond.initializeDiamondCut(targets[i], calls[i]);

            unchecked {
                ++i;
            }
        }
    }
}
