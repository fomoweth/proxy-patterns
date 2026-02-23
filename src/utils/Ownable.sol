// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title  Ownable
/// @notice Authorization mixin that provides basic access control with a single owner.
/// @author fomoweth
abstract contract Ownable {
    /// @notice Thrown when owner initialization is attempted more than once.
    error AlreadyInitialized();

    /// @notice Thrown when the provided account address is invalid.
    error InvalidAccount();

    /// @notice Thrown when an unauthorized account attempts a restricted operation.
    error Unauthorized();

    /// @notice Emitted when ownership is transferred from `previousOwner` to `newOwner`.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Precomputed event topic for {OwnershipTransferred}.
    /// @dev    keccak256(bytes("OwnershipTransferred(address,address)"))
    bytes32 private constant OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE =
        0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0;

    /// @notice Storage slot for the owner address.
    /// @dev    bytes32(~uint256(uint32(bytes4(keccak256("OWNER_SLOT")))))
    bytes32 private constant OWNER_SLOT = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffff9d564fd;

    /// @notice Restricts access to the current owner.
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /// @notice Returns the current owner of the contract.
    /// @return account The address of the owner.
    function owner() public view virtual returns (address account) {
        assembly ("memory-safe") {
            account := sload(OWNER_SLOT)
        }
    }

    /// @notice Renounces ownership, leaving the contract without an owner.
    function renounceOwnership() public payable virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /// @notice Transfers ownership of the contract to a new account.
    /// @param  account The address of the new owner.
    function transferOwnership(address account) public payable virtual onlyOwner {
        _checkAccount(account);
        _transferOwnership(account);
    }

    /// @notice Initializes ownership by setting the initial owner to `account`.
    /// @dev    Must be called exactly once during construction or initialization.
    ///         Reverts with {AlreadyInitialized} if an owner has already been set.
    function _initializeOwner(address account) internal virtual {
        assembly ("memory-safe") {
            if sload(OWNER_SLOT) {
                mstore(0x00, 0x0dc149f0) // AlreadyInitialized()
                revert(0x1c, 0x04)
            }
        }
        _checkAccount(account);
        _transferOwnership(account);
    }

    /// @notice Sets the owner to `account`.
    /// @dev    Emits {OwnershipTransferred} with the previous owner and the new owner.
    function _transferOwnership(address account) internal virtual {
        assembly ("memory-safe") {
            account := shr(0x60, shl(0x60, account))
            log3(0x00, 0x00, OWNERSHIP_TRANSFERRED_EVENT_SIGNATURE, sload(OWNER_SLOT), account)
            sstore(OWNER_SLOT, or(account, shl(0xff, iszero(account))))
        }
    }

    /// @notice Validates that `msg.sender` is the current owner.
    /// @dev    Reverts with {Unauthorized} if `msg.sender` is not the owner.
    function _checkOwner() internal view virtual {
        assembly ("memory-safe") {
            if iszero(eq(caller(), sload(OWNER_SLOT))) {
                mstore(0x00, 0x82b42900) // Unauthorized()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Validates that `account` is a nonzero address.
    /// @dev    Reverts with {InvalidAccount} if `account` is the zero address.
    function _checkAccount(address account) internal pure virtual {
        assembly ("memory-safe") {
            if iszero(shl(0x60, account)) {
                mstore(0x00, 0x6d187b28) // InvalidAccount()
                revert(0x1c, 0x04)
            }
        }
    }
}
