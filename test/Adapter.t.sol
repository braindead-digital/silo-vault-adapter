// test/Adapter.t.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Adapter} from "@/Adapter.sol";
import {IAdapter} from "@/interfaces/IAdapter.sol";
import {ISiloVault, MarketAllocation} from "@/interfaces/ISiloVault.sol";
import {console2} from "forge-std/console2.sol";

contract MockSiloVault {
    function totalAssets() external view returns (uint256) {
        return 1000 * 1e6; // 1000 USDC
    }

    function reallocate(MarketAllocation[] calldata _allocations) external {}
}

contract AdapterTest is Test {
    Adapter adapter;
    address admin;
    address worker;
    address siloVault;

    function setUp() public {
        admin = makeAddr("admin");
        worker = makeAddr("worker");
        siloVault = address(new MockSiloVault());

        vm.startPrank(admin);
        adapter = new Adapter();
        adapter.initialize(admin, ISiloVault(siloVault));
        adapter.grantRole(adapter.WORKER_ROLE(), worker);
        vm.stopPrank();
    }

    /// @notice Benchmark the gas used by the rebalanceToWeights function
    function testBenchmarkRebalance() public {
        // Create test data
        IAdapter.WeightInfo[] memory weights = new IAdapter.WeightInfo[](10);
        for (uint256 i; i < 10; i++) {
            weights[i] = IAdapter.WeightInfo({weight: 1e17, asset: makeAddr(string(abi.encodePacked("asset", i)))});
        }

        vm.startPrank(worker);

        // Take snapshot before each test
        uint256 snapshot1 = vm.snapshot();
        uint256 gasUsedAssembly = measureGas(weights);
        vm.revertTo(snapshot1);

        // Log results
        console2.log("Gas used (assembly):", gasUsedAssembly);

        vm.stopPrank();
    }

    function measureGas(IAdapter.WeightInfo[] memory weights) internal returns (uint256) {
        uint256 startGas = gasleft();
        adapter.rebalanceToWeights(weights);
        return startGas - gasleft();
    }
}
