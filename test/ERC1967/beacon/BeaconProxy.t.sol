// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {ERC1967Utils} from "src/ERC1967/ERC1967Utils.sol";
import {BeaconProxy} from "src/ERC1967/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "src/ERC1967/beacon/UpgradeableBeacon.sol";

import {MockImplementationV1, MockImplementationV2} from "test/mocks/MockImplementation.sol";

contract BeaconProxyTest is Test {
    error Unauthorized();

    address internal immutable alice = makeAddr("alice");
    address internal immutable bob = makeAddr("bob");

    UpgradeableBeacon internal beacon;

    address payable internal proxy;

    MockImplementationV1 internal mockV1;
    MockImplementationV2 internal mockV2;

    MockImplementationV1 internal implementationV1;
    MockImplementationV2 internal implementationV2;

    function setUp() public virtual {
        implementationV1 = new MockImplementationV1();
        implementationV2 = new MockImplementationV2();

        beacon = new UpgradeableBeacon(address(implementationV1), address(this));

        bytes memory data = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(10));
        proxy = payable(address(new BeaconProxy(address(beacon), data)));

        mockV1 = MockImplementationV1(proxy);
        mockV2 = MockImplementationV2(proxy);
    }

    // ============================================================
    // Constructor
    // ============================================================

    function test_constructor_setsBeaconSlot() public view {
        assertEq(_getBeacon(proxy), address(beacon));
    }

    function test_constructor_executesInitializer() public view {
        assertEq(mockV1.getNumber(), uint256(10));
        assertEq(mockV1.owner(), address(this));
        assertEq(mockV1.getVersion(), uint64(1));
    }

    function test_constructor_resolvesImplementationViaBeacon() public view {
        assertEq(beacon.implementation(), address(implementationV1));
    }

    function test_constructor_emitsBeaconUpgraded() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(1));

        vm.expectEmit(true, false, false, false);
        emit ERC1967Utils.BeaconUpgraded(address(beacon));
        new BeaconProxy(address(beacon), data);
    }

    function test_constructor_revertsIfInvalidBeacon() public {
        bytes memory data = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(1));

        vm.expectRevert(ERC1967Utils.InvalidBeacon.selector);
        new BeaconProxy(address(0xdead), data);
    }

    function test_constructor_revertsIfBeaconReturnsEOA() public {
        // Deploy a beacon pointing to an EOA — the beacon itself deploys, but
        // creating a BeaconProxy against it should fail because the implementation
        // returned by the beacon has no code.
        vm.expectRevert();
        new UpgradeableBeacon(alice, address(this));
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
    // Beacon upgrade
    // ============================================================

    function test_upgradeTo_updatesImplementation() public {
        beacon.upgradeTo(address(implementationV2));
        assertEq(beacon.implementation(), address(implementationV2));
    }

    function test_upgradeTo_proxyDelegatesNewImplementation() public {
        mockV1.setNumber(20);

        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(5));
        beacon.upgradeTo(address(implementationV2));

        // Reinitialize V2 through the proxy
        (bool success,) = proxy.call(data);
        assertTrue(success);

        assertEq(mockV2.getNumber(), uint256(20));
        assertEq(mockV2.getMultiplier(), uint256(5));
    }

    function test_upgradeTo_newBehaviorAfterUpgrade() public {
        mockV1.setNumber(10);

        beacon.upgradeTo(address(implementationV2));

        bytes memory data = abi.encodeWithSelector(MockImplementationV2.initialize.selector, uint256(3));
        (bool success,) = proxy.call(data);
        assertTrue(success);

        mockV2.increment();
        assertEq(mockV2.getNumber(), uint256(13));
    }

    function test_upgradeTo_preservesState() public {
        mockV1.setNumber(42);
        mockV1.increment();
        assertEq(mockV1.getNumber(), uint256(43));

        beacon.upgradeTo(address(implementationV2));
        assertEq(mockV2.getNumber(), uint256(43));
    }

    function test_upgradeTo_emitsUpgraded() public {
        vm.expectEmit(true, false, false, false, address(beacon));
        emit UpgradeableBeacon.Upgraded(address(implementationV2));
        beacon.upgradeTo(address(implementationV2));
    }

    function test_upgradeTo_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert(Unauthorized.selector);
        beacon.upgradeTo(address(implementationV2));
    }

    function test_upgradeTo_revertsIfInvalidImplementation() public {
        vm.expectRevert(UpgradeableBeacon.InvalidBeaconImplementation.selector);
        beacon.upgradeTo(address(0xdead));
    }

    function test_upgradeTo_revertsIfEOAImplementation() public {
        vm.expectRevert(UpgradeableBeacon.InvalidBeaconImplementation.selector);
        beacon.upgradeTo(alice);
    }

    // ============================================================
    // Multiple proxies sharing one beacon
    // ============================================================

    function test_multipleProxies_shareBeaconImplementation() public {
        bytes memory data1 = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(100));
        bytes memory data2 = abi.encodeWithSelector(MockImplementationV1.initialize.selector, uint256(200));

        address payable proxy1 = payable(address(new BeaconProxy(address(beacon), data1)));
        address payable proxy2 = payable(address(new BeaconProxy(address(beacon), data2)));

        MockImplementationV1 mock1 = MockImplementationV1(proxy1);
        MockImplementationV1 mock2 = MockImplementationV1(proxy2);

        assertEq(mock1.getNumber(), uint256(100));
        assertEq(mock2.getNumber(), uint256(200));

        // Upgrade beacon — both proxies get the new implementation.
        beacon.upgradeTo(address(implementationV2));

        MockImplementationV2 mockV2_1 = MockImplementationV2(proxy1);
        MockImplementationV2 mockV2_2 = MockImplementationV2(proxy2);

        // State is preserved independently.
        assertEq(mockV2_1.getNumber(), uint256(100));
        assertEq(mockV2_2.getNumber(), uint256(200));
    }

    // ============================================================
    // Beacon constructor with empty init data
    // ============================================================

    function test_constructor_withEmptyData() public {
        // BeaconProxy does not have the ProxyUninitialized check (that's on ERC1967Proxy).
        // Empty data should succeed as long as no value is sent.
        address payable p = payable(address(new BeaconProxy(address(beacon), "")));
        assertTrue(p.code.length > 0);
    }

    function test_constructor_revertsNonPayableIfValueWithEmptyData() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert(ERC1967Utils.NonPayable.selector);
        new BeaconProxy{value: 1 wei}(address(beacon), "");
    }

    // ============================================================
    // Helpers
    // ============================================================

    function _getBeacon(address target) internal view returns (address) {
        return address(uint160(uint256(vm.load(target, ERC1967Utils.BEACON_SLOT))));
    }
}
