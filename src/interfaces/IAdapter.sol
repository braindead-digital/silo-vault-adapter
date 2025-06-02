// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

interface IAdapter {
    struct WeightInfo {
        uint256 weight;
        address asset;
    }

    event Rebalance(WeightInfo[] weights, bytes32 extraData);

    function rebalanceToWeights(WeightInfo[] calldata _weights, bytes32 _extraData) external;
}
