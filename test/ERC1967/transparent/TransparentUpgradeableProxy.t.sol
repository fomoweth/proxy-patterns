// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "src/ERC1967/ERC1967Proxy.sol";
import {TransparentUpgradeableProxy} from "src/ERC1967/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "src/ERC1967/transparent/ProxyAdmin.sol";

import {MockTargetV1, MockTargetV2} from "test/mocks/MockTarget.sol";
import {BaseTest} from "test/BaseTest.sol";

contract TransparentUpgradeableProxyTest is BaseTest {
    address payable internal proxy;
    ProxyAdmin internal proxyAdmin;

    MockTargetV2 internal mockProxy;
    MockTargetV1 internal mockTargetV1;
    MockTargetV2 internal mockTargetV2;

    function setUp() public {
        mockTargetV1 = new MockTargetV1();
        mockTargetV2 = new MockTargetV2();

        vm.expectEmit(true, true, true, true);
        emit ERC1967Utils.Upgraded(address(mockTargetV1));

        bytes memory data = abi.encodeWithSelector(MockTargetV1.initialize.selector, initialNumber);
        proxy = payable(address(new TransparentUpgradeableProxy(address(mockTargetV1), address(this), data)));
        proxyAdmin = ProxyAdmin(vm.computeCreateAddress(proxy, uint256(1)));
        mockProxy = MockTargetV2(proxy);
    }

    function test_constructor_setsImplementationSlot() public view {
        assertEq(getImplementation(proxy), address(mockTargetV1));
    }

    function test_constructor_setsAdminSlot() public view {
        assertEq(getAdmin(proxy), address(proxyAdmin));
        assertContract(address(proxyAdmin));
    }

    function test_constructor_setsAdminOwner() public view {
        assertEq(proxyAdmin.owner(), address(this));
    }

    function test_constructor_executesInitializer() public view {
        assertEq(mockProxy.owner(), address(this));
        assertEq(mockProxy.getVersion(), uint64(1));
        assertEq(mockProxy.getNumber(), initialNumber);
    }

    function test_constructor_revertsIfEmptyData() public {
        vm.expectRevert(ERC1967Proxy.ProxyUninitialized.selector);
        new TransparentUpgradeableProxy(address(mockTargetV1), address(this), "");
    }

    function test_constructor_revertsIfInvalidImplementation() public {
        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        bytes memory data = abi.encodeWithSelector(MockTargetV1.initialize.selector, initialNumber);
        new TransparentUpgradeableProxy(eoa, address(this), data);
    }

    function test_UPGRADE_INTERFACE_VERSION() public view {
        assertEq(proxyAdmin.UPGRADE_INTERFACE_VERSION(), "5.0.0");
    }

    function test_delegation_delegatesToImplementation() public {
        mockProxy.increment();
        assertEq(mockProxy.getNumber(), initialNumber + 1);

        mockProxy.setNumber(uint256(42));
        assertEq(mockProxy.getNumber(), uint256(42));
    }

    function test_delegation_revertsIfUnauthorized() public impersonate(eoa) {
        vm.expectRevert(Unauthorized.selector);
        mockProxy.setNumber(uint256(99));
    }

    function test_delegation_acceptsEther() public impersonate(eoa) {
        uint256 msgValue = 1 ether;
        deal(eoa, msgValue);
        sendETH(proxy, msgValue);
        assertEq(proxy.balance, msgValue);
    }

    function test_proxyAdmin_cannotCallImplementationFunctions() public impersonate(address(proxyAdmin)) {
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        mockProxy.increment();

        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        mockProxy.getNumber();
    }

    function test_proxyAdmin_cannotSendEmptyCalldata() public impersonate(address(proxyAdmin)) {
        uint256 msgValue = 1 ether;
        vm.deal(address(proxyAdmin), msgValue);
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        sendETH(proxy, msgValue);
    }

    function test_proxyAdmin_cannotCallArbitrarySelectors() public impersonate(address(proxyAdmin)) {
        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        (bool success,) = proxy.call(abi.encodeWithSelector(bytes4(0xdeadbeef)));

        vm.expectRevert(TransparentUpgradeableProxy.ProxyDeniedAdminAccess.selector);
        (success,) = proxy.call(abi.encodeWithSelector(bytes4(0x00000000)));
    }

    function test_upgradeAndCall_updatesImplementationSlot() public {
        vm.expectEmit(true, true, true, true, proxy);
        emit ERC1967Utils.Upgraded(address(mockTargetV2));

        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        proxyAdmin.upgradeAndCall(proxy, address(mockTargetV2), data);

        assertEq(getImplementation(proxy), address(mockTargetV2));
    }

    function test_upgradeToAndCall_executesInitializer() public {
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        proxyAdmin.upgradeAndCall(proxy, address(mockTargetV2), data);

        assertEq(mockProxy.getVersion(), uint64(2));
        assertEq(mockProxy.getStep(), initialStep);
    }

    function test_upgradeAndCall_preservesState() public {
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        proxyAdmin.upgradeAndCall(proxy, address(mockTargetV2), data);

        assertEq(mockProxy.owner(), address(this));
        assertEq(mockProxy.getNumber(), initialNumber);
    }

    function test_upgradeAndCall_newBehaviorAfterUpgrade() public {
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        proxyAdmin.upgradeAndCall(proxy, address(mockTargetV2), data);

        assertEq(mockProxy.getNumber(), initialNumber);
        mockProxy.increment();
        assertEq(mockProxy.getNumber(), initialNumber + initialStep);
    }

    function test_upgradeAndCall_revertsIfNotAuthorized() public impersonate(eoa) {
        vm.expectRevert(Unauthorized.selector);
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        proxyAdmin.upgradeAndCall(proxy, address(mockTargetV2), data);
    }

    function test_upgradeAndCall_revertsIfInvalidImplementation() public {
        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        proxyAdmin.upgradeAndCall(proxy, eoa, data);
    }

    function test_upgradeAndCall_withEmptyData() public {
        proxyAdmin.upgradeAndCall(proxy, address(mockTargetV2), "");
        assertEq(getImplementation(proxy), address(mockTargetV2));
    }

    function test_upgradeAndCall_revertsNonPayableIfValueWithEmptyData() public {
        vm.expectRevert(ERC1967Utils.NonPayable.selector);
        proxyAdmin.upgradeAndCall{value: 1 ether}(proxy, address(mockTargetV2), "");
    }
}
