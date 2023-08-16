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

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Invariants is StdInvariant, Test {
    DeployDecentralizedStableCoin deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external {
        deployer = new DeployDecentralizedStableCoin();
        (dsc, dsce, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        // targetContract(address(dsce)); // used to tell foundry what contract we are fuzz and invariant testing. Patrick said "we're telling foundry to go wild on this"
        handler = new Handler(dsce, dsc);
        targetContract(address(handler));
    }

    // get the value of all the collateral in the protocol, compare it to all the debt (dsc)
    function invariant_protocolMustHaveMoreThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, totalWbtcDeposited);

        console.log("weth value: ", wethValue);
        console.log("wbtc value: ", wbtcValue);
        console.log("total supply: ", totalSupply);
        console.log("Times mint called: ", handler.timesMintIsCalled());

        assert(wethValue + wbtcValue >= totalSupply); // needs to be greater than or equal because if there is nothing in the engine, then total collateral and supply will be the same
    }

    // it is always good practice to have a function like this that tests to make sure that all get functions do not revert.
    // this is to make sure we are not breaking our invariant tests
    function invariant_gettersShouldNotRevert() public view {
        dsce.getCollateralTokens();
    }
}
