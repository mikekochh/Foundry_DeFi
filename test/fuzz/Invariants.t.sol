// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Invariants
 * @author Michael Koch
 * @notice
 *
 * Have our invariants aka properties
 * What are our invariants?
 * 1. The total supply of DSC should be less than the total value of collateral
 * 2. Getter view functions should never revert <- evergreen invariant
 *
 *
 */

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Invariants is StdInvariant, Test {
    DeployDecentralizedStableCoin deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDecentralizedStableCoin();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        targetContract(address(dsce)); // used to tell foundry what contract we are fuzz and invariant testing. Patrick said "we're telling foundry to go wild on this"
    }

    // get the value of all the collateral in the protocol, compare it to all the debt (dsc)
    function invariant_protocolMustHaveMoreThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

        assert(wethValue + wbtcValue >= totalSupply); // needs to be greater than or equal because if there is nothing in the engine, then total collateral and supply will be the same
    }
}
