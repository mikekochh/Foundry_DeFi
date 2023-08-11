// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DSCEngineTest is Test {
    error DSCEngine__BreaksHealthFactor(uint256);

    DeployDecentralizedStableCoin deployer = new DeployDecentralizedStableCoin();
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public USER_LIQUIDATE = makeAddr("user2");
    uint256 public constant AMOUNT_COLLATERAL = 5 ether; // which is really $10k, since ETH is at $2k
    uint256 public constant AMOUNT_COLLATERAL_TO_REDEEM = 1 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 5 ether;
    uint256 public constant AMOUNT_DSC = 1000 ether; // while this is actually $1k
    uint256 public constant AMOUNT_DSC_TO_BURN = 500 ether;
    uint256 public constant AMOUNT_COLLATERAL_BAD = 0.1 ether;
    uint256 public constant BROKEN_HEALTH_FACTOR = 100000000000000000; // 100,000,000,000,000,000

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

    modifier depositCollateralAndMintDsc() {
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC);
        _;
    }

    modifier depositCollateralAndMintDscCustomPrank() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, AMOUNT_DSC);
        vm.stopPrank();
        _;
    }

    modifier updateCollateralPositionToBeBad() {
        dsce.updateCollateralPositionForTestingPurposesOnly(USER, weth, AMOUNT_COLLATERAL_BAD);
        _;
    }

    modifier prankUser() {
        vm.startPrank(USER);
        _;
        vm.stopPrank();
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

    function testRevertsIfCollateralZero() public prankUser mintUserWeth {
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
    }

    function testRevertsWithUnapprovedCollateral() public prankUser {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
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
    function testRevertIfHealthFactorIsBroken()
        public
        prankUser
        mintUserWeth
        depositCollateralAndMintDsc
        updateCollateralPositionToBeBad
    {
        vm.expectRevert(
            abi.encodePacked(abi.encodeWithSelector(DSCEngine__BreaksHealthFactor.selector, BROKEN_HEALTH_FACTOR))
        );
        dsce.revertIfHealthFactorIsBroken(USER);
    }

    // write a function for testing if user has zero minted DSC, to throw a revert error saying cannot divide by zero
    function testRevertIfUserHasZeroDscAndTriesToGetHealthFactor() public mintUserWeth depositedCollateral {
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorUnavailableWithoutDSC.selector);
        dsce.getHealthFactor(USER);
    }

    // write a function for testing if health factor function is returning correct health factor
    function testGetHealthFactor() public prankUser mintUserWeth depositCollateralAndMintDsc {
        uint256 expectedHealthFactor = 5e18;
        uint256 acutalHealthFactor = dsce.getHealthFactor(USER);
        assertEq(expectedHealthFactor, acutalHealthFactor);
    }

    // write a function for testing if updating position makes health factor too low, then revert transaction

    // write a function where if someone's health factor is fine and someone tries to liquidate them, expect revert
    function testLiquidateHealthFactorOK() public mintUserWeth depositCollateralAndMintDscCustomPrank {
        vm.prank(USER_LIQUIDATE);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOK.selector);
        dsce.liquidate(ethUsdPriceFeed, USER, AMOUNT_COLLATERAL);
    }

    // write a function testing the burn

    // // write a function where if someone's health factor is too low, then have the ability to liquidate them
    function testLiquidate()
        public
        mintUserWeth
        depositCollateralAndMintDscCustomPrank
        updateCollateralPositionToBeBad
    {
        vm.startPrank(USER_LIQUIDATE);
        dsce.liquidate(ethUsdPriceFeed, USER, AMOUNT_COLLATERAL_BAD);
        vm.stopPrank();
    }

    // function for getAccountCollateralValue
    function testGetAccountCollateralValue() public prankUser mintUserWeth depositCollateralAndMintDsc {
        uint256 actualAccountCollateralValue = dsce.getAccountCollateralValue(USER);
        assertEq(actualAccountCollateralValue, dsce.getUsdValue(weth, AMOUNT_COLLATERAL));
    }

    function testGetAccountInformation() public prankUser mintUserWeth depositCollateralAndMintDsc {
        (uint256 actualTotalDscMinted, uint256 actualCollateralValueInUsd) = dsce.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = AMOUNT_DSC;
        uint256 expectedCollateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);
        assertEq(actualTotalDscMinted, expectedTotalDscMinted);
        assertEq(actualCollateralValueInUsd, expectedCollateralValueInUsd);
    }

    // function for testing if redeem collateral is working correctly
    // function testRedeemCollateral() public mintUserWeth depositCollateralAndMintDsc {
    //     vm.startPrank(USER);
    //     dsce.redeemCollateral(weth, AMOUNT_COLLATERAL);
    //     vm.stopPrank();
    // }

    function testRedeemCollateralForDsc() public prankUser mintUserWeth depositCollateralAndMintDsc {
        dsc.approve(address(dsce), AMOUNT_DSC);
        dsce.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL_TO_REDEEM, AMOUNT_DSC_TO_BURN);
    }

    function testRedeemCollateralForDscExpectRevert() public prankUser mintUserWeth depositCollateralAndMintDsc {}
}
