// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Invariant Tests
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

contract InvariantsTest is StdInvariant, Test {
    DeployDecentralizedStableCoin deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;

    function setUp() external {
        deployer = new DeployDecentralizedStableCoin();
        (dsc, dsce, config) = deployer.run();
    }
}
