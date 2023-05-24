// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

import "../library/types/AccountTypes.sol";
import "../library/types/PerpTypes.sol";

interface ISettlement {
    event AccountRegister(bytes32 indexed accountId, bytes32 indexed brokerId, address indexed addr);
    event AccountDeposit(
        bytes32 indexed accountId,
        address indexed addr,
        bytes32 indexed tokenSymbol,
        uint256 srcChainId,
        uint256 tokenAmount
    );
    event AccountWithdraw(
        bytes32 indexed accountId,
        address indexed addr,
        bytes32 indexed tokenSymbol,
        uint256 dstChainId,
        uint256 tokenAmount
    );

    function accountRegister(AccountTypes.AccountRegister calldata accountRegister) external;
    function accountDeposit(AccountTypes.AccountDeposit calldata accountDeposit) external;
    function updateUserLedgerByTradeUpload(PrepTypes.FuturesTradeUpload calldata trade) external;
    function executeWithdrawAction(PrepTypes.WithdrawData calldata withdraw, uint256 eventId) external;
    function executeSettlement(PrepTypes.Settlement calldata settlement, uint256 eventId) external;
    function executeLiquidation(PrepTypes.Liquidation calldata liquidation, uint256 eventId) external;
}