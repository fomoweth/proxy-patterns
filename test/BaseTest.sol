// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CommonBase} from "forge-std/Base.sol";
import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";

abstract contract BaseTest is Test {
    error Unauthorized();

    address internal constant eoa = address(0xdeadbeef);

    uint256 internal constant initialNumber = 10;
    uint256 internal constant initialStep = 3;
    uint256 internal snapshotId = type(uint256).max;

    modifier impersonate(address account) {
        vm.startPrank(account);
        _;
        vm.stopPrank();
    }

    function revertToState() internal virtual {
        if (snapshotId != type(uint256).max) vm.revertToState(snapshotId);
        snapshotId = vm.snapshotState();
    }

    function sendETH(address recipient, uint256 value) internal virtual {
        assembly ("memory-safe") {
            if iszero(call(gas(), recipient, value, codesize(), 0x00, codesize(), 0x00)) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0x00, returndatasize())
                revert(ptr, returndatasize())
            }
        }
    }

    function getImplementation(address proxy) internal view virtual returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }

    function getAdmin(address proxy) internal view virtual returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    }

    function getBeacon(address proxy) internal view virtual returns (address) {
        return address(uint160(uint256(vm.load(proxy, ERC1967Utils.BEACON_SLOT))));
    }

    function isContract(address target) internal view returns (bool result) {
        assembly ("memory-safe") {
            result := iszero(iszero(extcodesize(target)))
        }
    }

    function assertContract(address target, string memory err) internal view virtual {
        vm.assertTrue(isContract(target), err);
    }

    function assertContract(address target) internal view virtual {
        vm.assertTrue(isContract(target));
    }

    function assertAddressZero(address target, string memory err) internal pure virtual {
        vm.assertEq(target, address(0), err);
    }

    function assertAddressZero(address target) internal pure virtual {
        vm.assertEq(target, address(0));
    }

    function assertNotAddressZero(address target, string memory err) internal pure virtual {
        vm.assertNotEq(target, address(0), err);
    }

    function assertNotAddressZero(address target) internal pure virtual {
        vm.assertNotEq(target, address(0));
    }

    function assertEq(bytes4[] memory left, bytes4[] memory right, string memory err) internal pure virtual {
        vm.assertEq(castToBytes32Array(left), castToBytes32Array(right), err);
    }

    function assertEq(bytes4[] memory left, bytes4[] memory right) internal pure virtual {
        vm.assertEq(castToBytes32Array(left), castToBytes32Array(right));
    }

    function castToBytes32Array(bytes4[] memory input) internal pure virtual returns (bytes32[] memory output) {
        assembly ("memory-safe") {
            output := input
        }
    }
}
