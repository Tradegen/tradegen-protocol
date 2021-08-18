// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;

//Interfaces
import './interfaces/Ubeswap/IUniswapV2Router02.sol';
import './interfaces/IERC20.sol';
import './interfaces/ISettings.sol';
import './interfaces/IAssetHandler.sol';
import './interfaces/IAddressResolver.sol';
import './interfaces/IBaseUbeswapAdapter.sol';
import './interfaces/Ubeswap/IUbeswapPoolManager.sol';
import './interfaces/Ubeswap/IStakingRewards.sol';
import './interfaces/Ubeswap/IUniswapV2Factory.sol';

//Libraries
import './libraries/SafeMath.sol';

contract TestUbeswapAdapter is IBaseUbeswapAdapter {
    using SafeMath for uint;

    // Max slippage percent allowed
    uint public constant override MAX_SLIPPAGE_PERCENT = 10; //10% slippage

    //Artificial CELO price used for testing
    uint public USDperCELO = 5;

    IAddressResolver public immutable ADDRESS_RESOLVER;

    constructor(IAddressResolver addressResolver) {
        ADDRESS_RESOLVER = addressResolver;
    }

    /* ========== VIEWS ========== */

    /**
    * @dev Given an input asset address, returns the price of the asset in cUSD
    * @param currencyKey Address of the asset
    * @return uint Price of the asset
    */
    function getPrice(address currencyKey) public view override returns(uint) {
        address assetHandlerAddress = ADDRESS_RESOLVER.getContractAddress("AssetHandler");
        address stableCoinAddress = IAssetHandler(assetHandlerAddress).getStableCoinAddress();

        //Check if currency key is cUSD
        if (currencyKey == stableCoinAddress)
        {
            return 10 ** 18;
        }

        require(currencyKey != address(0), "Invalid currency key");

        //Return CELO price
        return USDperCELO.mul(10 ** 18);
    }

    /**
    * @dev Given an input asset amount, returns the maximum output amount of the other asset
    * @notice Assumes numberOfTokens is multiplied by currency's decimals before function call
    * @param numberOfTokens Number of tokens
    * @param currencyKeyIn Address of the asset to be swap from
    * @param currencyKeyOut Address of the asset to be swap to
    * @return uint Amount out of the asset
    */
    function getAmountsOut(uint numberOfTokens, address currencyKeyIn, address currencyKeyOut) public view override returns (uint) {
        address assetHandlerAddress = ADDRESS_RESOLVER.getContractAddress("AssetHandler");
        address ubeswapRouterAddress = ADDRESS_RESOLVER.getContractAddress("UbeswapRouter");
        address stableCoinAddress = IAssetHandler(assetHandlerAddress).getStableCoinAddress();

        require(currencyKeyIn != address(0), "Invalid currency key in");
        require(currencyKeyOut != address(0), "Invalid currency key out");
        require(IAssetHandler(assetHandlerAddress).isValidAsset(currencyKeyIn) || currencyKeyIn == stableCoinAddress, "BaseUbeswapAdapter: CurrencyKeyIn is not available");
        require(IAssetHandler(assetHandlerAddress).isValidAsset(currencyKeyOut) || currencyKeyOut == stableCoinAddress, "BaseUbeswapAdapter: CurrencyKeyOut is not available");
        require(numberOfTokens > 0, "Number of tokens must be greater than 0");

        address[] memory path = new address[](2);
        path[0] = currencyKeyIn;
        path[1] = currencyKeyOut;
        uint[] memory amounts = IUniswapV2Router02(ubeswapRouterAddress).getAmountsOut(numberOfTokens, path);

        return amounts[1];
    }

    /**
    * @dev Given the target output asset amount, returns the amount of input asset needed
    * @param numberOfTokens Target amount of output asset
    * @param currencyKeyIn Address of the asset to be swap from
    * @param currencyKeyOut Address of the asset to be swap to
    * @return uint Amount out input asset needed
    */
    function getAmountsIn(uint numberOfTokens, address currencyKeyIn, address currencyKeyOut) public view override returns (uint) {
        address assetHandlerAddress = ADDRESS_RESOLVER.getContractAddress("AssetHandler");
        address ubeswapRouterAddress = ADDRESS_RESOLVER.getContractAddress("UbeswapRouter");
        address stableCoinAddress = IAssetHandler(assetHandlerAddress).getStableCoinAddress();

        require(currencyKeyIn != address(0), "Invalid currency key in");
        require(currencyKeyOut != address(0), "Invalid currency key out");
        require(IAssetHandler(assetHandlerAddress).isValidAsset(currencyKeyIn) || currencyKeyIn == stableCoinAddress, "BaseUbeswapAdapter: CurrencyKeyIn is not available");
        require(IAssetHandler(assetHandlerAddress).isValidAsset(currencyKeyOut) || currencyKeyOut == stableCoinAddress, "BaseUbeswapAdapter: CurrencyKeyOut is not available");
        require(numberOfTokens > 0, "Number of tokens must be greater than 0");

        address[] memory path = new address[](2);
        path[0] = currencyKeyIn;
        path[1] = currencyKeyOut;
        uint[] memory amounts = IUniswapV2Router02(ubeswapRouterAddress).getAmountsIn(numberOfTokens, path);

        return amounts[1];
    }

    /**
    * @dev Sets the CELO price to the specified price
    * @notice This function is only used for testing
    * @param newPrice Price of CELO per USD
    */
    function setPrice(uint newPrice) public {
        USDperCELO = newPrice;
    }

    /**
    * @dev Returns the farm address and liquidity pool address for each available farm on Ubeswap
    * @return address[] memory The farm address for each available farm
    */
    function getAvailableUbeswapFarms() public view override returns (address[] memory) {
        address ubeswapPoolManagerAddress = ADDRESS_RESOLVER.getContractAddress("UbeswapPoolManager");

        uint numberOfAvailableFarms = IUbeswapPoolManager(ubeswapPoolManagerAddress).poolsCount();
        address[] memory farmAddresses = new address[](numberOfAvailableFarms);

        for (uint i = 0; i < numberOfAvailableFarms; i++)
        {
            farmAddresses[i] = IUbeswapPoolManager(ubeswapPoolManagerAddress).poolsByIndex(i);
        }

        return farmAddresses;
    }

    /**
    * @dev Returns the address of a token pair
    * @param tokenA First token in pair
    * @param tokenB Second token in pair
    * @return address The pair's address
    */
    function getPair(address tokenA, address tokenB) public view override returns (address) {
        require(tokenA != address(0), "BaseUbeswapAdapter: invalid address for tokenA");
        require(tokenB != address(0), "BaseUbeswapAdapter: invalid address for tokenB");

        address uniswapV2FactoryAddress = ADDRESS_RESOLVER.getContractAddress("UniswapV2Factory");

        return IUniswapV2Factory(uniswapV2FactoryAddress).getPair(tokenA, tokenB);
    }

    /**
    * @dev Returns the amount of UBE rewards available for the pool in the given farm
    * @param poolAddress Address of the pool
    * @param farmAddress Address of the farm on Ubeswap
    * @return uint Amount of UBE available
    */
    function getAvailableRewards(address poolAddress, address farmAddress) public view override returns (uint) {
        require(poolAddress != address(0), "BaseUbeswapAdapter: invalid pool address");

        return IStakingRewards(farmAddress).earned(poolAddress);
    }

    /**
    * @dev Calculates the amount of tokens in a pair
    * @param tokenA First token in pair
    * @param tokenB Second token in pair
    * @param numberOfLPTokens Number of LP tokens for the given pair
    * @return (uint, uint) The number of tokens for tokenA and tokenB
    */
    function getTokenAmountsFromPair(address tokenA, address tokenB, uint numberOfLPTokens) public view override returns (uint, uint) {
        address pair = getPair(tokenA, tokenB);
        require(pair != address(0), "BaseUbeswapAdapter: invalid address for pair");

        uint pairBalanceTokenA = IERC20(tokenA).balanceOf(pair);
        uint pairBalanceTokenB = IERC20(tokenB).balanceOf(pair);
        uint totalSupply = IERC20(pair).totalSupply();

        uint amountA = pairBalanceTokenA.mul(numberOfLPTokens).div(totalSupply);
        uint amountB = pairBalanceTokenB.mul(numberOfLPTokens).div(totalSupply);

        return (amountA, amountB);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
    * @dev Get the decimals of an asset
    * @return number of decimals of the asset
    */
    function _getDecimals(address asset) internal view returns (uint) {
        return IERC20(asset).decimals();
    }

    /* ========== EVENTS ========== */

    event Swapped(address fromAsset, address toAsset, uint fromAmount, uint receivedAmount, uint timestamp);
    event AddedLiquidity(address addressAddedFrom, address tokenA, address tokenB, uint amountA, uint amountB, uint numberOfLPTokens, uint timestamp);
    event RemovedLiquidity(address addressRemovedFrom, address tokenA, address tokenB, uint amountAReceived, uint amountBReceived, uint timestamp);
}