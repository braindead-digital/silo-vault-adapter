// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

interface IAdapter {
    struct WeightInfo {
        uint256 weight;
        address asset;
    }

    function rebalanceToWeights(WeightInfo[] calldata _weights) external;
}
