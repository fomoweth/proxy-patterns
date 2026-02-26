// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UUPSUpgradeable} from "src/ERC1967/uups/UUPSUpgradeable.sol";
import {LibDiamond} from "src/diamond/LibDiamond.sol";
import {Initializable} from "src/utils/Initializable.sol";
import {Ownable} from "src/utils/Ownable.sol";
import {StorageSlot} from "test/utils/StorageSlot.sol";

contract MockTargetV1 is Initializable, Ownable {
    uint256 internal _number;

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 initialNumber) public virtual initializer {
        _initializeOwner(msg.sender);
        _number = initialNumber;
    }

    function getVersion() public view virtual returns (uint64) {
        return _getInitializedVersion();
    }

    function getNumber() public view virtual returns (uint256) {
        return _number;
    }

    function setNumber(uint256 newNumber) public virtual onlyOwner {
        _number = newNumber;
    }

    function increment() public virtual onlyOwner {
        _number++;
    }

    function decrement() public virtual onlyOwner {
        _number--;
    }

    receive() external payable virtual {}
}

contract MockTargetV2 is MockTargetV1 {
    uint256 internal _step;

    function initialize(uint256 initialStep) public virtual override reinitializer(2) {
        _step = initialStep;
    }

    function getStep() public view virtual returns (uint256) {
        return _step;
    }

    function setStep(uint256 newStep) public virtual onlyOwner {
        _step = newStep;
    }

    function increment() public virtual override onlyOwner {
        _number += _step;
    }

    function decrement() public virtual override onlyOwner {
        _number -= _step;
    }
}

contract UUPSMockTargetV1 is MockTargetV1, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}

contract UUPSMockTargetV2 is MockTargetV2, UUPSUpgradeable {
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}

contract UUPSMockTargetInvalid is UUPSMockTargetV1 {
    bytes32 internal immutable _slot;

    constructor(bytes32 slot) {
        _slot = slot;
    }

    function proxiableUUID() public view virtual override notDelegated returns (bytes32) {
        return _slot;
    }
}

contract MockTargetFacetV1 {
    using StorageSlot for bytes32;

    bytes32 private constant NUMBER_POS = keccak256("mock.target.facet.number");

    function getNumber() external view returns (uint256) {
        return NUMBER_POS.getUint256Slot().value;
    }

    function setNumber(uint256 newNumber) external {
        LibDiamond.enforceIsContractOwner();
        NUMBER_POS.getUint256Slot().value = newNumber;
    }

    function increment() external {
        LibDiamond.enforceIsContractOwner();
        NUMBER_POS.getUint256Slot().value++;
    }

    function decrement() external {
        LibDiamond.enforceIsContractOwner();
        NUMBER_POS.getUint256Slot().value--;
    }
}

contract MockTargetFacetV2 {
    using StorageSlot for bytes32;

    bytes32 private constant NUMBER_POS = keccak256("mock.target.facet.number");

    bytes32 private constant STEP_POS = keccak256("mock.target.facet.step");

    function getNumber() external view returns (uint256) {
        return NUMBER_POS.getUint256Slot().value;
    }

    function setNumber(uint256 newNumber) external {
        LibDiamond.enforceIsContractOwner();
        NUMBER_POS.getUint256Slot().value = newNumber;
    }

    function getStep() external view returns (uint256) {
        return STEP_POS.getUint256Slot().value;
    }

    function setStep(uint256 newStep) external {
        LibDiamond.enforceIsContractOwner();
        STEP_POS.getUint256Slot().value = newStep;
    }

    function increment() external {
        LibDiamond.enforceIsContractOwner();
        NUMBER_POS.getUint256Slot().value += STEP_POS.getUint256Slot().value;
    }

    function decrement() external {
        LibDiamond.enforceIsContractOwner();
        NUMBER_POS.getUint256Slot().value -= STEP_POS.getUint256Slot().value;
    }
}
