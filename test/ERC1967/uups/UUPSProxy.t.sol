// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "src/ERC1967/ERC1967Proxy.sol";
import {UUPSProxy} from "src/ERC1967/uups/UUPSProxy.sol";
import {UUPSUpgradeable} from "src/ERC1967/uups/UUPSUpgradeable.sol";

import {
    MockUUPSImplementationV1,
    MockUUPSImplementationV2,
    MockUUPSBadUUID
} from "test/mocks/MockUUPSImplementation.sol";
import {MockImplementationV1} from "test/mocks/MockImplementation.sol";

contract UUPSProxyTest is Test {
    error Unauthorized();

    address internal immutable alice = makeAddr("alice");
    address internal immutable bob = makeAddr("bob");

    address payable internal proxy;

    MockUUPSImplementationV1 internal mockV1;
    MockUUPSImplementationV2 internal mockV2;

    MockUUPSImplementationV1 internal implementationV1;
    MockUUPSImplementationV2 internal implementationV2;

    function setUp() public virtual {
        implementationV1 = new MockUUPSImplementationV1();
        implementationV2 = new MockUUPSImplementationV2();

        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV1.initialize.selector, uint256(10));
        proxy = payable(address(new UUPSProxy(address(implementationV1), data)));

        mockV1 = MockUUPSImplementationV1(proxy);
        mockV2 = MockUUPSImplementationV2(proxy);
    }

    // ============================================================
    // Constructor
    // ============================================================

    function test_constructor_setsImplementationSlot() public view {
        assertEq(_getImplementation(proxy), address(implementationV1));
    }

    function test_constructor_executesInitializer() public view {
        assertEq(mockV1.getNumber(), uint256(10));
        assertEq(mockV1.owner(), address(this));
        assertEq(mockV1.getVersion(), uint64(1));
    }

    function test_constructor_revertsIfEmptyData() public {
        vm.expectRevert(ERC1967Proxy.ProxyUninitialized.selector);
        new UUPSProxy(address(implementationV1), "");
    }

    function test_constructor_revertsIfInvalidImplementation() public {
        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV1.initialize.selector, uint256(1));

        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        new UUPSProxy(address(0xdead), data);
    }

    function test_constructor_emitsUpgraded() public {
        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV1.initialize.selector, uint256(1));

        vm.expectEmit(true, false, false, false);
        emit ERC1967Utils.Upgraded(address(implementationV1));
        new UUPSProxy(address(implementationV1), data);
    }

    // ============================================================
    // Delegation
    // ============================================================

    function test_delegation_delegatesToImplementation() public view {
        assertEq(mockV1.getNumber(), uint256(10));
    }

    function test_delegation_stateIsPersisted() public {
        mockV1.setNumber(42);
        assertEq(mockV1.getNumber(), uint256(42));
    }

    function test_delegation_increment() public {
        mockV1.increment();
        assertEq(mockV1.getNumber(), uint256(11));
    }

    function test_delegation_revertsIfUnauthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        mockV1.setNumber(99);
    }

    function test_delegation_acceptsEther() public {
        deal(alice, 1 ether);
        vm.prank(alice);
        (bool success,) = proxy.call{value: 0.5 ether}("");
        assertTrue(success);
        assertEq(proxy.balance, 0.5 ether);
    }

    // ============================================================
    // UUPS upgrade (via proxy)
    // ============================================================

    function test_upgradeToAndCall_updatesImplementationSlot() public {
        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV2.initialize.selector, uint256(2));
        mockV1.upgradeToAndCall(address(implementationV2), data);

        assertEq(_getImplementation(proxy), address(implementationV2));
    }

    function test_upgradeToAndCall_preservesState() public {
        mockV1.setNumber(42);

        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV2.initialize.selector, uint256(3));
        mockV1.upgradeToAndCall(address(implementationV2), data);

        assertEq(mockV2.getNumber(), uint256(42));
    }

    function test_upgradeToAndCall_executesInitializer() public {
        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV2.initialize.selector, uint256(5));
        mockV1.upgradeToAndCall(address(implementationV2), data);

        assertEq(mockV2.getMultiplier(), uint256(5));
    }

    function test_upgradeToAndCall_newBehaviorAfterUpgrade() public {
        mockV1.setNumber(10);

        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV2.initialize.selector, uint256(3));
        mockV1.upgradeToAndCall(address(implementationV2), data);

        mockV2.increment();
        assertEq(mockV2.getNumber(), uint256(13));
    }

    function test_upgradeToAndCall_emitsUpgraded() public {
        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV2.initialize.selector, uint256(2));

        vm.expectEmit(true, false, false, false, proxy);
        emit ERC1967Utils.Upgraded(address(implementationV2));
        mockV1.upgradeToAndCall(address(implementationV2), data);
    }

    function test_upgradeToAndCall_withEmptyData() public {
        mockV1.upgradeToAndCall(address(implementationV2), "");
        assertEq(_getImplementation(proxy), address(implementationV2));
    }

    function test_upgradeToAndCall_revertsNonPayableIfValueWithEmptyData() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(ERC1967Utils.NonPayable.selector);
        mockV1.upgradeToAndCall{value: 1 wei}(address(implementationV2), "");
    }

    // ============================================================
    // UUPS authorization
    // ============================================================

    function test_upgradeToAndCall_revertsIfNotOwner() public {
        bytes memory data = abi.encodeWithSelector(MockUUPSImplementationV2.initialize.selector, uint256(2));

        vm.prank(alice);
        vm.expectRevert(Unauthorized.selector);
        mockV1.upgradeToAndCall(address(implementationV2), data);
    }

    // ============================================================
    // UUPS context checks
    // ============================================================

    function test_proxiableUUID_returnsImplementationSlot() public view {
        // Called on the implementation directly (not through proxy), should succeed.
        assertEq(implementationV1.proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    }

    function test_proxiableUUID_revertsIfCalledThroughProxy() public {
        // proxiableUUID has notDelegated modifier, should revert via proxy.
        vm.expectRevert(UUPSUpgradeable.UnauthorizedCallContext.selector);
        mockV1.proxiableUUID();
    }

    function test_upgradeToAndCall_revertsIfCalledOnImplementationDirectly() public {
        // upgradeToAndCall has onlyProxy modifier, should revert when called directly.
        vm.expectRevert(UUPSUpgradeable.UnauthorizedCallContext.selector);
        implementationV1.upgradeToAndCall(address(implementationV2), "");
    }

    function test_UPGRADE_INTERFACE_VERSION() public view {
        assertEq(implementationV1.UPGRADE_INTERFACE_VERSION(), "5.0.0");
    }

    // ============================================================
    // UUPS UUID validation
    // ============================================================

    function test_upgradeToAndCall_revertsIfBadUUID() public {
        MockUUPSBadUUID badImpl = new MockUUPSBadUUID();

        vm.expectRevert();
        mockV1.upgradeToAndCall(address(badImpl), "");
    }

    function test_upgradeToAndCall_revertsIfNonUUPSImplementation() public {
        // A contract with no proxiableUUID function at all should fail.
        MockImplementationV1 nonUUPS = new MockImplementationV1();

        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        mockV1.upgradeToAndCall(address(nonUUPS), "");
    }

    // ============================================================
    // Helpers
    // ============================================================

    function _getImplementation(address target) internal view returns (address) {
        return address(uint160(uint256(vm.load(target, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }
}
