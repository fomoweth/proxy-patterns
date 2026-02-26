// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "src/ERC1967/ERC1967Proxy.sol";
import {UUPSProxy} from "src/ERC1967/uups/UUPSProxy.sol";
import {UUPSUpgradeable} from "src/ERC1967/uups/UUPSUpgradeable.sol";

import {
    MockTargetV1,
    MockTargetV2,
    UUPSMockTargetV1,
    UUPSMockTargetV2,
    UUPSMockTargetInvalid
} from "test/mocks/MockTarget.sol";
import {BaseTest} from "test/BaseTest.sol";

contract UUPSProxyTest is BaseTest {
    address payable internal proxy;

    UUPSMockTargetV2 internal mockProxy;
    UUPSMockTargetV1 internal mockTargetV1;
    UUPSMockTargetV2 internal mockTargetV2;

    function setUp() public {
        mockTargetV1 = new UUPSMockTargetV1();
        mockTargetV2 = new UUPSMockTargetV2();

        vm.expectEmit(true, true, true, true);
        emit ERC1967Utils.Upgraded(address(mockTargetV1));

        bytes memory data = abi.encodeWithSelector(MockTargetV1.initialize.selector, initialNumber);
        proxy = payable(address(new UUPSProxy(address(mockTargetV1), data)));
        mockProxy = UUPSMockTargetV2(proxy);
    }

    function test_constructor_setsImplementationSlot() public view {
        assertEq(getImplementation(proxy), address(mockTargetV1));
    }

    function test_constructor_executesInitializer() public view {
        assertEq(mockProxy.owner(), address(this));
        assertEq(mockProxy.getVersion(), uint64(1));
        assertEq(mockProxy.getNumber(), initialNumber);
    }

    function test_constructor_revertsIfEmptyData() public {
        vm.expectRevert(ERC1967Proxy.ProxyUninitialized.selector);
        new UUPSProxy(address(mockTargetV1), "");
    }

    function test_constructor_revertsIfInvalidImplementation() public {
        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        bytes memory data = abi.encodeWithSelector(MockTargetV1.initialize.selector, initialNumber);
        new UUPSProxy(eoa, data);
    }

    function test_UPGRADE_INTERFACE_VERSION() public view {
        assertEq(mockTargetV1.UPGRADE_INTERFACE_VERSION(), "5.0.0");
    }

    function test_proxiableUUID_returnsImplementationSlot() public view {
        assertEq(mockTargetV1.proxiableUUID(), ERC1967Utils.IMPLEMENTATION_SLOT);
    }

    function test_proxiableUUID_revertsIfCalledThroughProxy() public {
        vm.expectRevert(UUPSUpgradeable.UnauthorizedCallContext.selector);
        mockProxy.proxiableUUID();
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

    function test_upgradeToAndCall_updatesImplementationSlot() public {
        vm.expectEmit(true, true, true, true, proxy);
        emit ERC1967Utils.Upgraded(address(mockTargetV2));

        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        mockProxy.upgradeToAndCall(address(mockTargetV2), data);

        assertEq(getImplementation(proxy), address(mockTargetV2));
    }

    function test_upgradeToAndCall_executesInitializer() public {
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        mockProxy.upgradeToAndCall(address(mockTargetV2), data);

        assertEq(mockProxy.getVersion(), uint64(2));
        assertEq(mockProxy.getStep(), initialStep);
    }

    function test_upgradeToAndCall_preservesState() public {
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        mockProxy.upgradeToAndCall(address(mockTargetV2), data);

        assertEq(mockProxy.owner(), address(this));
        assertEq(mockProxy.getNumber(), initialNumber);
    }

    function test_upgradeToAndCall_newBehaviorAfterUpgrade() public {
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        mockProxy.upgradeToAndCall(address(mockTargetV2), data);

        mockProxy.increment();
        assertEq(mockProxy.getNumber(), initialNumber + initialStep);
    }

    function test_upgradeToAndCall_withEmptyData() public {
        mockProxy.upgradeToAndCall(address(mockTargetV2), "");
        assertEq(getImplementation(proxy), address(mockTargetV2));
    }

    function test_upgradeToAndCall_revertsNonPayableIfValueWithEmptyData() public {
        vm.expectRevert(ERC1967Utils.NonPayable.selector);
        mockProxy.upgradeToAndCall{value: 1 ether}(address(mockTargetV2), "");
    }

    function test_upgradeToAndCall_revertsIfNotAuthorized() public impersonate(eoa) {
        vm.expectRevert(Unauthorized.selector);
        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        mockProxy.upgradeToAndCall(address(mockTargetV2), data);
    }

    function test_upgradeToAndCall_revertsIfCalledOnImplementationDirectly() public {
        vm.expectRevert(UUPSUpgradeable.UnauthorizedCallContext.selector);
        mockTargetV1.upgradeToAndCall(address(mockTargetV2), "");
    }

    function test_upgradeToAndCall_revertsIfBadUUID() public {
        bytes32 slot = keccak256("uups.invalid.slot");
        UUPSMockTargetInvalid invalidUUPS = new UUPSMockTargetInvalid(slot);

        vm.expectRevert(abi.encodeWithSelector(ERC1967Utils.UnsupportedProxiableUUID.selector, slot));
        mockProxy.upgradeToAndCall(address(invalidUUPS), "");
    }

    function test_upgradeToAndCall_revertsIfNonUUPSImplementation() public {
        MockTargetV1 nonUUPS = new MockTargetV1();
        vm.expectRevert(ERC1967Utils.InvalidImplementation.selector);
        mockProxy.upgradeToAndCall(address(nonUUPS), "");
    }
}
