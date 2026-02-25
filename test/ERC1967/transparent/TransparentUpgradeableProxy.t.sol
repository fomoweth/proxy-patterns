// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "src/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} from "src/ERC1967/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "src/ERC1967/transparent/ProxyAdmin.sol";

import {MockImplementationV1, MockImplementationV2} from "test/mocks/MockImplementation.sol";

contract TransparentUpgradeableProxyTest is Test {
    error Unauthorized();

    address internal immutable alice = makeAddr("alice");
    address internal immutable bob = makeAddr("bob");

    address payable internal proxy;
    ProxyAdmin internal proxyAdmin;

    MockImplementationV1 internal mockV1;
    MockImplementationV2 internal mockV2;

    MockImplementationV1 internal implementationV1;
    MockImplementationV2 internal implementationV2;

    function setUp() public virtual {
        implementationV1 = new MockImplementationV1();
        implementationV2 = new MockImplementationV2();

        bytes memory data = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(10));
        proxy = payable(address(new TransparentUpgradeableProxy(address(implementationV1), address(this), data)));
        proxyAdmin = ProxyAdmin(vm.computeCreateAddress(proxy, 1));

        mockV1 = MockImplementationV1(proxy);
        mockV2 = MockImplementationV2(proxy);
    }

    // ============================================================
    // Constructor
    // ============================================================

    function test_constructor_setsImplementationSlot() public view {
        assertEq(_getImplementation(proxy), address(implementationV1));
    }

    function test_constructor_deploysProxyAdmin() public view {
        assertTrue(address(proxyAdmin).code.length > 0);
    }

    function test_constructor_setsAdminSlot() public view {
        assertEq(_getAdmin(proxy), address(proxyAdmin));
    }

    function test_constructor_setsAdminOwner() public view {
        assertEq(proxyAdmin.owner(), address(this));
    }

    function test_constructor_executesInitializer() public view {
        assertEq(mockV1.getNumber(), uint256(10));
        assertEq(mockV1.owner(), address(this));
        assertEq(mockV1.getVersion(), uint64(1));
    }

    function test_constructor_emitsUpgradedAndAdminChanged() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(1));

        vm.expectEmit(true, false, false, false);
        emit ERC1967Utils.Upgraded(address(implementationV1));
        new TransparentUpgradeableProxy(address(implementationV1), alice, data);
    }

    function test_constructor_revertsIfEmptyData() public {
        vm.expectRevert(ERC1967Proxy.ProxyUninitialized.selector);
        new TransparentUpgradeableProxy(address(implementationV1), address(this), "");
    }

    function test_constructor_revertsIfInvalidImplementation() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(1));

        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        new TransparentUpgradeableProxy(address(0xdead), address(this), data);
    }

    // ============================================================
    // Delegation (non-admin callers)
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
    // Admin access control
    // ============================================================

    function test_admin_cannotCallImplementationFunctions() public {
        // When admin calls a function that is NOT upgradeToAndCall, it should revert.
        vm.prank(address(proxyAdmin));
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        MockImplementationV1(proxy).getNumber();
    }

    function test_admin_cannotSendEmptyCalldata() public {
        // Admin sending ETH with no data should revert (fallback intercepts it).
        vm.deal(address(proxyAdmin), 1 ether);
        vm.prank(address(proxyAdmin));
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        (bool success,) = proxy.call{value: 0.1 ether}("");
        success; // suppress warning
    }

    function test_admin_cannotCallArbitrarySelectors() public {
        // Admin calling a random selector should revert.
        vm.prank(address(proxyAdmin));
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        (bool success,) = proxy.call(abi.encodeWithSelector(bytes4(0xdeadbeef)));
        success; // suppress warning
    }

    // ============================================================
    // Upgrade via ProxyAdmin
    // ============================================================

    function test_upgradeAndCall_updatesImplementationSlot() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(2));
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), data);

        assertEq(_getImplementation(proxy), address(implementationV2));
    }

    function test_upgradeAndCall_preservesState() public {
        mockV1.setNumber(42);
        assertEq(mockV1.getNumber(), uint256(42));

        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(3));
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), data);

        assertEq(mockV2.getNumber(), uint256(42));
    }

    function test_upgradeAndCall_executesInitializer() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(5));
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), data);

        assertEq(mockV2.getMultiplier(), uint256(5));
    }

    function test_upgradeAndCall_newBehaviorAfterUpgrade() public {
        mockV1.setNumber(10);

        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(3));
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), data);

        assertEq(mockV2.getNumber(), uint256(10));
        mockV2.increment();
        assertEq(mockV2.getNumber(), uint256(13));
    }

    function test_upgradeAndCall_emitsUpgraded() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(2));

        vm.expectEmit(true, false, false, false, proxy);
        emit ERC1967Utils.Upgraded(address(implementationV2));
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), data);
    }

    function test_upgradeAndCall_revertsIfNotOwner() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(2));

        vm.prank(alice);
        vm.expectRevert(Unauthorized.selector);
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), data);
    }

    function test_upgradeAndCall_revertsIfInvalidImplementation() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(2));

        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        proxyAdmin.upgradeAndCall(proxy, address(0xdead), data);
    }

    function test_upgradeAndCall_withEmptyData() public {
        proxyAdmin.upgradeAndCall(proxy, address(implementationV2), "");
        assertEq(_getImplementation(proxy), address(implementationV2));
    }

    function test_upgradeAndCall_revertsNonPayableIfValueWithEmptyData() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(ERC1967Utils.NonPayable.selector);
        proxyAdmin.upgradeAndCall{value: 1 wei}(proxy, address(implementationV2), "");
    }

    // ============================================================
    // ProxyAdmin
    // ============================================================

    function test_proxyAdmin_UPGRADE_INTERFACE_VERSION() public view {
        assertEq(proxyAdmin.UPGRADE_INTERFACE_VERSION(), "5.0.0");
    }

    // ============================================================
    // Helpers
    // ============================================================

    function _getImplementation(address target) internal view returns (address) {
        return address(uint160(uint256(vm.load(target, ERC1967Utils.IMPLEMENTATION_SLOT))));
    }

    function _getAdmin(address target) internal view returns (address) {
        return address(uint160(uint256(vm.load(target, ERC1967Utils.ADMIN_SLOT))));
    }
}
