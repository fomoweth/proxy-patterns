// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";
import {BeaconProxy} from "src/ERC1967/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "src/ERC1967/beacon/UpgradeableBeacon.sol";

import {MockTargetV1, MockTargetV2} from "test/mocks/MockTarget.sol";
import {BaseTest} from "test/BaseTest.sol";

contract BeaconProxyTest is BaseTest {
    UpgradeableBeacon internal beacon;
    address payable internal proxy;

    MockTargetV2 internal mockProxy;
    MockTargetV1 internal mockTargetV1;
    MockTargetV2 internal mockTargetV2;

    function setUp() public {
        mockTargetV1 = new MockTargetV1();
        mockTargetV2 = new MockTargetV2();

        beacon = new UpgradeableBeacon(address(mockTargetV1), address(this));

        vm.expectEmit(true, true, true, true);
        emit ERC1967Utils.BeaconUpgraded(address(beacon));

        bytes memory data = abi.encodeWithSelector(MockTargetV1.initialize.selector, initialNumber);
        proxy = payable(address(new BeaconProxy(address(beacon), data)));
        mockProxy = MockTargetV2(proxy);
    }

    function test_constructor_setsBeaconSlot() public view {
        assertEq(getBeacon(proxy), address(beacon));
    }

    function test_constructor_resolvesImplementationViaBeacon() public view {
        assertEq(beacon.implementation(), address(mockTargetV1));
    }

    function test_constructor_executesInitializer() public view {
        assertEq(mockProxy.owner(), address(this));
        assertEq(mockProxy.getVersion(), uint64(1));
        assertEq(mockProxy.getNumber(), initialNumber);
    }

    function test_constructor_withEmptyData() public {
        assertContract(address(new BeaconProxy(address(beacon), "")));
    }

    function test_constructor_revertsIfInvalidBeacon() public {
        vm.expectRevert(ERC1967Utils.InvalidBeacon.selector);
        bytes memory data = abi.encodeWithSelector(MockTargetV1.initialize.selector, initialNumber);
        new BeaconProxy(eoa, data);
    }

    function test_constructor_revertsNonPayableIfValueWithEmptyData() public {
        vm.expectRevert(ERC1967Utils.NonPayable.selector);
        new BeaconProxy{value: 1 ether}(address(beacon), "");
    }

    function test_constructor_revertsIfInvalidBeaconImplementation() public {
        vm.expectRevert(UpgradeableBeacon.InvalidBeaconImplementation.selector);
        new UpgradeableBeacon(eoa, address(this));
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

    function test_upgradeTo_updatesImplementation() public {
        vm.expectEmit(true, true, true, true, address(beacon));
        emit UpgradeableBeacon.Upgraded(address(mockTargetV2));

        beacon.upgradeTo(address(mockTargetV2));
        assertEq(beacon.implementation(), address(mockTargetV2));
    }

    function test_upgradeTo_executesInitializer() public {
        beacon.upgradeTo(address(mockTargetV2));

        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        (bool success,) = proxy.call(data);
        assertTrue(success);

        assertEq(mockProxy.getVersion(), uint64(2));
        assertEq(mockProxy.getStep(), initialStep);
    }

    function test_upgradeTo_preservesState() public {
        beacon.upgradeTo(address(mockTargetV2));
        assertEq(mockProxy.owner(), address(this));
        assertEq(mockProxy.getNumber(), initialNumber);
    }

    function test_upgradeTo_newBehaviorAfterUpgrade() public {
        beacon.upgradeTo(address(mockTargetV2));

        bytes memory data = abi.encodeWithSelector(MockTargetV2.initialize.selector, initialStep);
        (bool success,) = proxy.call(data);
        assertTrue(success);

        mockProxy.increment();
        assertEq(mockProxy.getNumber(), initialNumber + initialStep);
    }

    function test_upgradeTo_revertsIfNotAuthorized() public impersonate(eoa) {
        vm.expectRevert(Unauthorized.selector);
        beacon.upgradeTo(address(mockTargetV2));
    }

    function test_upgradeTo_revertsIfInvalidImplementation() public {
        vm.expectRevert(UpgradeableBeacon.InvalidBeaconImplementation.selector);
        beacon.upgradeTo(eoa);
    }

    function test_multipleProxies_shareBeaconImplementation() public {
        uint256 value1 = uint256(100);
        uint256 value2 = uint256(200);
        uint256 value3 = uint256(300);

        bytes memory data1 = abi.encodeWithSelector(MockTargetV1.initialize.selector, value1);
        bytes memory data2 = abi.encodeWithSelector(MockTargetV1.initialize.selector, value2);
        bytes memory data3 = abi.encodeWithSelector(MockTargetV1.initialize.selector, value3);

        address payable proxy1 = payable(address(new BeaconProxy(address(beacon), data1)));
        address payable proxy2 = payable(address(new BeaconProxy(address(beacon), data2)));
        address payable proxy3 = payable(address(new BeaconProxy(address(beacon), data3)));

        assertEq(MockTargetV1(proxy1).getNumber(), value1);
        assertEq(MockTargetV1(proxy2).getNumber(), value2);
        assertEq(MockTargetV1(proxy3).getNumber(), value3);

        beacon.upgradeTo(address(mockTargetV2));

        assertEq(MockTargetV2(proxy1).getNumber(), value1);
        assertEq(MockTargetV2(proxy2).getNumber(), value2);
        assertEq(MockTargetV1(proxy3).getNumber(), value3);
    }
}
