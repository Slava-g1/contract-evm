// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../../src/interface/IVaultCrossChainManager.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract VaultCrossChainManagerMock is IVaultCrossChainManager, Ownable {
    function getDepositFee(VaultTypes.VaultDeposit memory data) external view override returns (uint256) {}

    function deposit(VaultTypes.VaultDeposit memory data) external override {}

    function burnFinish(RebalanceTypes.RebalanceBurnCCFinishData memory data) external override {}

    function mintFinish(RebalanceTypes.RebalanceMintCCFinishData memory data) external override {}

    function withdraw(VaultTypes.VaultWithdraw memory data) external override {}

    function setVault(address _vault) external override {}

    function setCrossChainRelay(address _crossChainRelay) external override {}

    function depositWithFee(VaultTypes.VaultDeposit memory _data) external payable override {}

    function depositWithFeeRefund(address refundReceiver, VaultTypes.VaultDeposit memory _data)
        external
        payable
        override
    {}
}
