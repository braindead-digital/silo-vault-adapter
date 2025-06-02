// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {ISiloVault, MarketAllocation} from "@/interfaces/ISiloVault.sol";
import {IAdapter} from "@/interfaces/IAdapter.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {SemVerLib} from "@/libs/SemVerLib.sol";
import {LibString} from "@/libs/LibString.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract Adapter is IAdapter, UUPSUpgradeable, AccessControlUpgradeable {
    ISiloVault public siloVault;

    bytes32 public constant VERSION = "1.0.0";
    uint256 public constant DP = 1e18; // Decimals precision

    bytes32 public constant WORKER_ROLE = keccak256("WORKER_ROLE");

    error InvalidVersion(bytes32 version);
    error InvalidWeights(uint256 sum);

    /// @notice Initializes the adapter
    /// @param _admin The address of the admin
    /// @param _siloVault The address of the silo vault
    function initialize(address _admin, ISiloVault _siloVault) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        siloVault = _siloVault;
    }

    ///// INTERNAL FUNCTIONS /////

    /// @notice Verifies the sum of the weights is less than the decimals precision
    /// @dev This function is used to verify the sum of the weights is 1 in 1e18 precision
    function _verifySum() internal pure {
        assembly {
            let offset := calldataload(0x04)
            let length := calldataload(add(add(0x04, offset), 0x00))
            let sum := 0

            let ptr := add(add(offset, 0x04), 0x20)

            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                sum := add(sum, calldataload(add(ptr, shl(6, i))))

                // 0xde0b6b3a7640000 = 1e18
                if gt(sum, 0xde0b6b3a7640000) {
                    mstore(0x00, 0x7c663b9200000000000000000000000000000000000000000000000000000000)
                    mstore(0x24, sum)
                    revert(0x00, 0x24)
                }
            }

            if iszero(eq(sum, 0xde0b6b3a7640000)) {
                mstore(0x00, 0x7c663b9200000000000000000000000000000000000000000000000000000000)
                mstore(0x24, sum)
                revert(0x00, 0x24)
            }
        }
    }

    /// EXTERNAL FUNCTIONS /////

    /// @notice Rebalances the vault to the given weights
    /// @param _weights The weights to rebalance to
    /// @param _extraData Extra data to be emitted in the event, used to build subgraph
    /// @dev The weights are in 1e18 precision
    function rebalanceToWeights(WeightInfo[] calldata _weights, bytes32 _extraData) external onlyRole(WORKER_ROLE) {
        _verifySum();
        uint256 totalAssets = siloVault.totalAssets();
        uint256 len = _weights.length;
        MarketAllocation[] memory allocations = new MarketAllocation[](len);
        for (uint256 i = 0; i < len; i++) {
            WeightInfo memory weightInfo = _weights[i];
            uint256 amount = i == len - 1
                ? type(uint256).max // As per SiloVault.reallocate, the last allocation should be type(uint256).max to supply all the remaining withdrawn liquidity
                : totalAssets * weightInfo.weight / DP; // Weight will be in DP precision
            allocations[i] = MarketAllocation({market: IERC4626(weightInfo.asset), assets: amount});
        }
        siloVault.reallocate(allocations);
        emit Rebalance(_weights, _extraData);
    }

    //// UPGRADEABLE FUNCTIONS /////

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool success, bytes memory data) = newImplementation.call("0xffa1ad74b"); // VERSION()
        if (!success) revert InvalidVersion(bytes32(0));
        string memory version = abi.decode(data, (string));
        bytes32 newVersion = LibString.toSmallString(version);
        if (SemVerLib.cmp(newVersion, VERSION) != 1) revert InvalidVersion(newVersion);
    }
}
