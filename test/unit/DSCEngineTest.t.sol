// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    DeployDecentralizedStableCoin deployer = new DeployDecentralizedStableCoin();
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    modifier mintUserWeth() {
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        _;
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function setUp() public {
        deployer = new DeployDecentralizedStableCoin();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();
    }

    ///////////////////////////
    // Constructor Tests //////
    ///////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////////
    // Price Tests //////
    /////////////////////

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount); // we are giving function address of wrapper eth we created, whether it is local or on testnet, it will go to address and get value the same
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public {
        uint256 usdAmont = 100 ether;
        // $2,000 / ETH = $100, ETH = 0.05
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmont);
        assertEq(expectedWeth, actualWeth);
    }

    /////////////////////////////////
    // depositCollateral Tests //////
    /////////////////////////////////

    function testRevertsIfCollateralZero() public mintUserWeth {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    // write a function that gets the account information of the USER
    function testCanDepositCollateralAndGetAccountInfo() public mintUserWeth depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    // write a function for testing if revert function for health factor is working correctly

    // write a function for testing if user has zero minted DSC, to throw a revert error saying cannot divide by zero
    function testRevertIfUserHasZeroDscAndTriesToGetHealthFactor() public mintUserWeth depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorUnavailableWithoutDSC.selector);
        uint256 healthFactor = dsce.getHealthFactor(USER);
    }

    // write a function for testing if health factor function is returning correct health factor
    // we probably need to refactor code so that if there is zero DSC in account, we do not get a divide by zero error
    function testGetHealthFactor() public mintUserWeth depositedCollateral {
        console.log("Health factor: ", dsce.getHealthFactor(USER));
        // uint256 healthFactor = dsce.getHealthFactor(USER);
    }
}
