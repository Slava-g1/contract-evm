// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../interface/IVault.sol";
import "../interface/IVaultCrossChainManager.sol";
import "../library/Utils.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Vault contract
/// @author Orderly_Rubick
/// @notice Vault is responsible for saving user's erc20 token.
/// EACH CHAIN SHOULD HAVE ONE Vault CONTRACT.
/// User can deposit erc20 (USDC) from Vault.
/// Only crossChainManager can approve withdraw request.
contract Vault is IVault, PausableUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeERC20 for IERC20;

    // The cross-chain manager address on Vault side
    address public crossChainManagerAddress;
    // An incrasing deposit id / nonce on Vault side
    uint64 public depositId;

    // A set to record the hash value of all allowed brokerIds  // brokerHash = keccak256(abi.encodePacked(brokerId))
    EnumerableSet.Bytes32Set private allowedBrokerSet;
    // A set to record the hash value of all allowed tokens  // tokenHash = keccak256(abi.encodePacked(tokenSymbol))
    EnumerableSet.Bytes32Set private allowedTokenSet;
    // A mapping from tokenHash to token contract address
    mapping(bytes32 => address) public allowedToken;

    /// @notice Require only cross-chain manager can call
    modifier onlyCrossChainManager() {
        if (msg.sender != crossChainManagerAddress) revert OnlyCrossChainManagerCanCall();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize() external override initializer {
        __Ownable_init();
        __Pausable_init();
    }

    /// @notice Change crossChainManager address
    function setCrossChainManager(address _crossChainManagerAddress) public override onlyOwner {
        if (_crossChainManagerAddress == address(0)) revert AddressZero();
        emit ChangeCrossChainManager(crossChainManagerAddress, _crossChainManagerAddress);
        crossChainManagerAddress = _crossChainManagerAddress;
    }

    /// @notice Add contract address for an allowed token given the tokenHash
    function setAllowedToken(bytes32 _tokenHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedTokenSet.add(_tokenHash);
        } else {
            allowedTokenSet.remove(_tokenHash);
        }
        emit SetAllowedToken(_tokenHash, _allowed);
    }

    /// @notice Add the hash value for an allowed brokerId
    function setAllowedBroker(bytes32 _brokerHash, bool _allowed) public override onlyOwner {
        if (_allowed) {
            allowedBrokerSet.add(_brokerHash);
        } else {
            allowedBrokerSet.remove(_brokerHash);
        }
        emit SetAllowedBroker(_brokerHash, _allowed);
    }

    /// @notice Change the token address for an allowed token, unusual case on Mainnet, but possible on Testnet
    function changeTokenAddressAndAllow(bytes32 _tokenHash, address _tokenAddress) public override onlyOwner {
        allowedToken[_tokenHash] = _tokenAddress;
        allowedTokenSet.add(_tokenHash);
        emit ChangeTokenAddressAndAllow(_tokenHash, _tokenAddress);
    }

    /// @notice Check if the given tokenHash is allowed on this Vault
    function getAllowedToken(bytes32 _tokenHash) public view override returns (address) {
        if (allowedTokenSet.contains(_tokenHash)) {
            return allowedToken[_tokenHash];
        } else {
            return address(0);
        }
    }

    /// @notice Check if the brokerHash is allowed on this Vault
    function getAllowedBroker(bytes32 _brokerHash) public view override returns (bool) {
        return allowedBrokerSet.contains(_brokerHash);
    }

    /// @notice Get all allowed tokenHash from this Vault
    function getAllAllowedToken() public view override returns (bytes32[] memory) {
        return allowedTokenSet.values();
    }

    /// @notice Get all allowed brokerIds hash from this Vault
    function getAllAllowedBroker() public view override returns (bytes32[] memory) {
        return allowedBrokerSet.values();
    }

    /// @notice The function to receive user deposit, VaultDepositFE type is defined in VaultTypes.sol
    function deposit(VaultTypes.VaultDepositFE calldata data) public override whenNotPaused {
        // require tokenAddress exist
        if (!allowedTokenSet.contains(data.tokenHash)) revert TokenNotAllowed();
        if (!allowedBrokerSet.contains(data.brokerHash)) revert BrokerNotAllowed();
        if (!Utils.validateAccountId(data.accountId, data.brokerHash, msg.sender)) revert AccountIdInvalid();
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        // avoid non-standard ERC20 tranferFrom bug
        tokenAddress.safeTransferFrom(msg.sender, address(this), data.tokenAmount);
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, msg.sender, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );
        IVaultCrossChainManager(crossChainManagerAddress).deposit(depositData);
        // emit deposit event
        emit AccountDeposit(data.accountId, msg.sender, depositId, data.tokenHash, data.tokenAmount);
    }

    /// @notice The function to allow users to deposit on behalf of another user, the receiver is the user who will receive the deposit
    function depositTo(address receiver, VaultTypes.VaultDepositFE calldata data) public whenNotPaused {
        if (!allowedTokenSet.contains(data.tokenHash)) revert TokenNotAllowed();
        if (!allowedBrokerSet.contains(data.brokerHash)) revert BrokerNotAllowed();
        if (!Utils.validateAccountId(data.accountId, data.brokerHash, receiver)) revert AccountIdInvalid();
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        // avoid non-standard ERC20 tranferFrom bug
        tokenAddress.safeTransferFrom(msg.sender, address(this), data.tokenAmount);
        // cross-chain tx to ledger
        VaultTypes.VaultDeposit memory depositData = VaultTypes.VaultDeposit(
            data.accountId, receiver, data.brokerHash, data.tokenHash, data.tokenAmount, _newDepositId()
        );
        IVaultCrossChainManager(crossChainManagerAddress).deposit(depositData);
        // emit deposit event
        emit AccountDepositTo(data.accountId, receiver, depositId, data.tokenHash, data.tokenAmount);
    }

    /// @notice user withdraw
    function withdraw(VaultTypes.VaultWithdraw calldata data) public override onlyCrossChainManager whenNotPaused {
        IERC20 tokenAddress = IERC20(allowedToken[data.tokenHash]);
        uint128 amount = data.tokenAmount - data.fee;
        // check balane gt amount
        if (tokenAddress.balanceOf(address(this)) < amount) {
            revert BalanceNotEnough(tokenAddress.balanceOf(address(this)), amount);
        }
        // transfer to user
        // avoid non-standard ERC20 tranfer bug
        tokenAddress.safeTransfer(data.receiver, amount);
        // send cross-chain tx to ledger
        IVaultCrossChainManager(crossChainManagerAddress).withdraw(data);
        // emit withdraw event
        emit AccountWithdraw(
            data.accountId,
            data.withdrawNonce,
            data.brokerHash,
            data.sender,
            data.receiver,
            data.tokenHash,
            data.tokenAmount,
            data.fee,
            block.timestamp
        );
    }

    /// @notice Update the depositId
    function _newDepositId() internal returns (uint64) {
        return ++depositId;
    }

    function emergencyPause() public onlyOwner {
        _pause();
    }

    function emergencyUnpause() public onlyOwner {
        _unpause();
    }
}
