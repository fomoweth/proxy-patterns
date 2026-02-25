// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "src/utils/Initializable.sol";
import {Ownable} from "src/utils/Ownable.sol";

contract MockImplementationV1 is Initializable, Ownable {
    event NumberSet(uint256 indexed previousNumber, uint256 indexed newNumber);

    uint256 internal _number;

    constructor() {
        disable();
    }

    function initialize(uint256 initialNumber) public virtual initializer {
        _initializeOwner(msg.sender);
        _number = initialNumber;
    }

    function reinitialize(uint64 version) public virtual reinitializer(version) {}

    function disable() public virtual {
        _disableInitializers();
    }

    function getVersion() public view virtual returns (uint64) {
        return _getInitializedVersion();
    }

    function getInitializing() public view virtual returns (bool) {
        return _isInitializing();
    }

    function getNumber() public view virtual returns (uint256) {
        return _number;
    }

    function setNumber(uint256 newNumber) public virtual onlyOwner {
        emit NumberSet(_number, newNumber);
        _number = newNumber;
    }

    function increment() public virtual onlyOwner {
        emit NumberSet(_number, _number++);
    }

    receive() external payable virtual {}
}

contract MockImplementationV2 is MockImplementationV1 {
    event MultiplierSet(uint256 indexed previousMultiplier, uint256 indexed newMultiplier);

    uint256 internal _multiplier;

    function initialize(uint256 initialMultiplier) public virtual override reinitializer(getVersion() + 1) {
        _multiplier = initialMultiplier;
    }

    function getMultiplier() public view virtual returns (uint256) {
        return _multiplier;
    }

    function setMultiplier(uint256 newMultiplier) public virtual onlyOwner {
        emit MultiplierSet(_multiplier, newMultiplier);
        _multiplier = newMultiplier;
    }

    function increment() public virtual override onlyOwner {
        emit NumberSet(_number, _number += _multiplier);
    }
}
