// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IERC173} from "./interfaces/IERC173.sol";

/// @title  LibDiamond
/// @notice Manages the selector-to-facet mapping using the Diamond Storage pattern.
library LibDiamond {
    error EmptyFunctionSelectors();

    error FunctionAlreadyExists(bytes4 selector);

    error FunctionFromSameFacet(bytes4 selector);

    error FunctionImmutable(bytes4 selector);

    error FunctionNotExists(bytes4 selector);

    error InitializationFailed();

    error InvalidInitContract();

    error InvalidFacetContract();

    error InvalidFacetCutAction();

    error Unauthorized();

    struct DiamondStorage {
        mapping(bytes4 selector => bytes32 facetAndSelectorPosition) selectorToFacetAndPosition;
        mapping(address facet => bytes4[] selectors) facetToSelectors;
        mapping(address facet => uint256 index) facetToPosition;
        address[] facetAddresses;
        mapping(bytes4 interfaceId => bool flag) supportedInterfaces;
        address owner;
    }

    /// @dev keccak256("diamond.standard.diamond.storage")
    bytes32 internal constant DIAMOND_STORAGE_SLOT = 0xc8fcad8db84d3cc18b4c41d551ea0ee66dd599cde068d998e57d5e09332c131c;

    function diamondStorage() internal pure returns (DiamondStorage storage $) {
        assembly ("memory-safe") {
            $.slot := DIAMOND_STORAGE_SLOT
        }
    }

    function contractOwner() internal view returns (address) {
        return diamondStorage().owner;
    }

    function enforceIsContractOwner() internal view {
        if (msg.sender != contractOwner()) revert Unauthorized();
    }

    function setContractOwner(address account) internal {
        DiamondStorage storage ds = diamondStorage();
        emit IERC173.OwnershipTransferred(ds.owner, ds.owner = account);
    }

    function diamondCut(IDiamondCut.FacetCut[] memory cuts, address init, bytes memory data) internal {
        DiamondStorage storage ds = diamondStorage();
        IDiamondCut.FacetCut memory cut;

        for (uint256 index = 0; index < cuts.length;) {
            if ((cut = cuts[index]).functionSelectors.length == 0) revert EmptyFunctionSelectors();

            if (cut.action == IDiamondCut.FacetCutAction.Add) {
                _addFunctions(ds, cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == IDiamondCut.FacetCutAction.Replace) {
                _replaceFunctions(ds, cut.facetAddress, cut.functionSelectors);
            } else if (cut.action == IDiamondCut.FacetCutAction.Remove) {
                _removeFunctions(ds, cut.facetAddress, cut.functionSelectors);
            } else {
                revert InvalidFacetCutAction();
            }

            unchecked {
                ++index;
            }
        }

        emit IDiamondCut.DiamondCut(cuts, init, data);
        if (init != address(0)) initializeDiamondCut(init, data);
    }

    function initializeDiamondCut(address init, bytes memory data) internal {
        assembly ("memory-safe") {
            if iszero(extcodesize(init)) {
                mstore(0x00, 0x8911c63a) // InvalidInitContract()
                revert(0x1c, 0x04)
            }

            if iszero(delegatecall(gas(), init, add(data, 0x20), mload(data), codesize(), 0x00)) {
                if iszero(returndatasize()) {
                    mstore(0x00, 0x19b991a8) // InitializationFailed()
                    revert(0x1c, 0x04)
                }

                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    function getFacetBySelector(bytes4 selector) internal view returns (address facet) {
        (facet,) = getFacetAndSelectorPosition(selector);
    }

    function getSelectorPosition(bytes4 selector) internal view returns (uint96 position) {
        (, position) = getFacetAndSelectorPosition(selector);
    }

    function getFacetAndSelectorPosition(bytes4 selector) internal view returns (address facet, uint96 position) {
        (facet, position) = _unpack(diamondStorage().selectorToFacetAndPosition[selector]);
    }

    function _addFunctions(DiamondStorage storage ds, address facet, bytes4[] memory selectors) private {
        _enforceFacetIsContract(facet);

        uint96 selectorPosition = uint96(ds.facetToSelectors[facet].length);
        if (selectorPosition == 0) {
            ds.facetToPosition[facet] = ds.facetAddresses.length;
            ds.facetAddresses.push(facet);
        }

        for (uint256 selectorIndex = 0; selectorIndex < selectors.length;) {
            bytes4 selector = selectors[selectorIndex];

            (address existingFacet,) = _unpack(ds.selectorToFacetAndPosition[selector]);
            if (existingFacet != address(0)) revert FunctionAlreadyExists(selector);

            _addFunction(ds, facet, selector, selectorPosition);

            unchecked {
                ++selectorIndex;
                ++selectorPosition;
            }
        }
    }

    function _replaceFunctions(DiamondStorage storage ds, address facet, bytes4[] memory selectors) private {
        _enforceFacetIsContract(facet);

        uint96 selectorPosition = uint96(ds.facetToSelectors[facet].length);
        if (selectorPosition == 0) {
            ds.facetToPosition[facet] = ds.facetAddresses.length;
            ds.facetAddresses.push(facet);
        }

        for (uint256 selectorIndex = 0; selectorIndex < selectors.length;) {
            bytes4 selector = selectors[selectorIndex];

            (address existingFacet,) = _unpack(ds.selectorToFacetAndPosition[selector]);
            if (existingFacet == facet) revert FunctionFromSameFacet(selector);

            _removeFunction(ds, existingFacet, selector);
            _addFunction(ds, facet, selector, selectorPosition);

            unchecked {
                ++selectorIndex;
                ++selectorPosition;
            }
        }
    }

    function _removeFunctions(DiamondStorage storage ds, address facet, bytes4[] memory selectors) private {
        if (facet != address(0)) revert InvalidFacetContract();

        for (uint256 selectorIndex = 0; selectorIndex < selectors.length;) {
            bytes4 selector = selectors[selectorIndex];

            (address existingFacet,) = _unpack(ds.selectorToFacetAndPosition[selector]);
            _removeFunction(ds, existingFacet, selector);

            unchecked {
                ++selectorIndex;
            }
        }
    }

    function _addFunction(DiamondStorage storage ds, address facet, bytes4 selector, uint96 position) private {
        ds.facetToSelectors[facet].push(selector);
        ds.selectorToFacetAndPosition[selector] = _pack(facet, position);
    }

    function _removeFunction(DiamondStorage storage ds, address facet, bytes4 selector) private {
        if (facet == address(0)) revert FunctionNotExists(selector);
        if (facet == address(this)) revert FunctionImmutable(selector);

        bytes32 facetAndPosition = ds.selectorToFacetAndPosition[selector];
        (, uint96 selectorPosition) = _unpack(facetAndPosition);
        uint256 lastSelectorPosition = ds.facetToSelectors[facet].length - 1;

        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetToSelectors[facet][lastSelectorPosition];
            ds.facetToSelectors[facet][selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector] = facetAndPosition;
        }

        ds.facetToSelectors[facet].pop();
        delete ds.selectorToFacetAndPosition[selector];

        if (ds.facetToSelectors[facet].length == 0) {
            uint256 facetPosition = ds.facetToPosition[facet];
            uint256 lastFacetPosition = ds.facetAddresses.length - 1;

            if (facetPosition != lastFacetPosition) {
                address lastFacet = ds.facetAddresses[lastFacetPosition];
                ds.facetAddresses[facetPosition] = lastFacet;
                ds.facetToPosition[lastFacet] = facetPosition;
            }

            ds.facetAddresses.pop();
            delete ds.facetToPosition[facet];
        }
    }

    function _enforceFacetIsContract(address target) private view {
        assembly ("memory-safe") {
            if iszero(extcodesize(target)) {
                mstore(0x00, 0xa0153210) // InvalidFacetContract()
                revert(0x1c, 0x04)
            }
        }
    }

    function _pack(address facet, uint96 position) private pure returns (bytes32 result) {
        assembly ("memory-safe") {
            result := or(shl(0xa0, position), shr(0x60, shl(0x60, facet)))
        }
    }

    function _unpack(bytes32 target) private pure returns (address facet, uint96 position) {
        assembly ("memory-safe") {
            facet := and(target, 0xffffffffffffffffffffffffffffffffffffffff)
            position := and(shr(0xa0, target), 0xffffffffffffffffffffffff)
        }
    }
}
