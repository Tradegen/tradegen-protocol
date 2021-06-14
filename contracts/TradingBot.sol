pragma solidity >=0.5.0;

//Libraries
import './libraries/SafeMath.sol';

//Interfaces
import './interfaces/IStrategyToken.sol';
import './interfaces/ITradingBot.sol';
import './interfaces/IIndicator.sol';
import './interfaces/IComparator.sol';
import './interfaces/IERC20.sol';
import './interfaces/IAddressResolver.sol';
import './interfaces/ITradingBotRewards.sol';
import './interfaces/ISettings.sol';
import './interfaces/IComponents.sol';

//Adapters
import './adapters/interfaces/IBaseUbeswapAdapter.sol';

contract TradingBot is ITradingBot {
    using SafeMath for uint;

    IERC20 public immutable STABLE_COIN;
    IERC20 public immutable TOKEN;
    IBaseUbeswapAdapter public immutable UBESWAP_ADAPTER;
    IAddressResolver public ADDRESS_RESOLVER;
    ITradingBotRewards public immutable TRADING_BOT_REWARDS;
    IComponents public COMPONENTS;

    //parameters
    Rule[] private _entryRules;
    Rule[] private _exitRules;
    uint public _maxTradeDuration;
    uint public _profitTarget; //assumes profit target is %
    uint public _stopLoss; //assumes stop loss is %
    address public _underlyingAsset;

    //state variables
    uint private _currentOrderSize;
    uint private _currentOrderEntryPrice;
    uint private _currentTradeDuration;

    address private _oracleAddress;
    address private _strategyAddress;

    constructor(uint[] memory entryRules,
                uint[] memory exitRules,
                uint maxTradeDuration,
                uint profitTarget,
                uint stopLoss,
                uint underlyingAssetID,
                IAddressResolver addressResolver) public onlyStrategy {

        ADDRESS_RESOLVER = addressResolver;
        TRADING_BOT_REWARDS = ITradingBotRewards(addressResolver.getContractAddress("TradingBotRewards"));
        COMPONENTS = IComponents(addressResolver.getContractAddress("Components"));

        _underlyingAsset = ISettings(addressResolver.getContractAddress("Settings")).getCurrencyKeyFromIndex(underlyingAssetID);

        STABLE_COIN = IERC20(ISettings(addressResolver.getContractAddress("Settings")).getStableCoinAddress());
        TOKEN = IERC20(_underlyingAsset);
        UBESWAP_ADAPTER = IBaseUbeswapAdapter(addressResolver.getContractAddress("BaseUbeswapAdapter"));
        
        _maxTradeDuration = maxTradeDuration;
        _profitTarget = profitTarget;
        _stopLoss = stopLoss;

        _strategyAddress = msg.sender;

        _generateRules(entryRules, exitRules);
    }

    /* ========== VIEWS ========== */

    /**
    * @dev Returns the index of each pool the user manages
    * @return (Rule[], Rule[], uint, uint, uint, address) The trading bot's entry rules, exit rules, max trade duration, profit target, stop loss, and underlying asset address
    */
    function getTradingBotParameters() public view override returns (Rule[] memory, Rule[] memory, uint, uint, uint, address) {
        return (_entryRules, _exitRules, _maxTradeDuration, _profitTarget, _stopLoss, _underlyingAsset);
    }

    /**
    * @dev Returns the address of the strategy associated with this bot
    * @return address The address of the strategy this bot belongs to
    */
    function getStrategyAddress() public view override onlyTradingBotRewards returns (address) {
        return _strategyAddress;
    }

    /**
    * @dev Returns whether the bot is in a trade
    * @return bool Whether the bot is currently in a trade
    */
    function checkIfBotIsInATrade() public view override returns (bool) {
        return (_currentOrderSize == 0);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
    * @dev Given the latest price from the bot's underlying asset, updates entry/exit rules and makes a trade depending on entry/exit rules
    * @param latestPrice Latest price from the underlying asset's oracle price feed
    */
    function onPriceFeedUpdate(uint latestPrice) public override onlyOracle {
        _updateRules(latestPrice);

        //check if bot is not in a trade
        if (_currentOrderSize == 0)
        {
            if (_checkEntryRules())
            {
                (_currentOrderSize, _currentOrderEntryPrice) = _placeOrder(true);
            }
        }
        else
        {
            if (_checkProfitTarget(latestPrice) || _checkStopLoss(latestPrice) || _currentTradeDuration >= _maxTradeDuration)
            {
                (, uint exitPrice) = _placeOrder(false);
                (bool profitOrLoss, uint amount) = _calculateProfitOrLoss(exitPrice);
                _currentOrderEntryPrice = 0;
                _currentOrderSize = 0;
                _currentTradeDuration = 0;
                TRADING_BOT_REWARDS.updateRewards(profitOrLoss, amount, IStrategyToken(_strategyAddress).getCirculatingSupply());
            }
            else
            {
                _currentTradeDuration = _currentTradeDuration.add(1);
            }
        }
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
    * @dev Places an order to buy/sell the bot's underling asset
    * @param buyOrSell Whether the order represents buying or selling
    * @return (uint, uint) Number of tokens received and the price executed
    */
    function _placeOrder(bool buyOrSell) private returns (uint, uint) {
        uint stableCoinBalance = STABLE_COIN.balanceOf(address(this));
        uint tokenBalance = TOKEN.balanceOf(address(this));
        uint tokenToUSD = UBESWAP_ADAPTER.getPrice(_underlyingAsset);
        uint numberOfTokens = buyOrSell ? stableCoinBalance : tokenBalance;
        uint amountInUSD = buyOrSell ? numberOfTokens.div(tokenToUSD) : numberOfTokens.mul(tokenToUSD);
        uint minAmountOut = buyOrSell ? numberOfTokens.mul(98).div(100) : amountInUSD.mul(98).div(100); //max slippage 2%
        uint numberOfTokensReceived;

        //buying
        if (buyOrSell)
        {
            numberOfTokensReceived = UBESWAP_ADAPTER.swapFromBot(address(STABLE_COIN), _underlyingAsset, amountInUSD, minAmountOut);
        }
        //selling
        else
        {
            numberOfTokensReceived = UBESWAP_ADAPTER.swapFromPool(_underlyingAsset, address(STABLE_COIN), numberOfTokens, minAmountOut);
        }

        emit PlacedOrder(address(this), block.timestamp, _underlyingAsset, 0, 0, buyOrSell);

        return (numberOfTokensReceived, tokenToUSD);
    } 

    /**
    * @dev Given the exit price of the bot's most recent trade, return the profit/loss for the trade
    * @param exitPrice Price of the bot's underlying asset when exiting the trade
    * @return (bool, uint) Whether the trade is profit/loss, and the amount of profit/loss
    */
    function _calculateProfitOrLoss(uint exitPrice) private view returns (bool, uint) {
        return (exitPrice >= _currentOrderEntryPrice) ? (true, exitPrice.sub(_currentOrderEntryPrice).div(_currentOrderEntryPrice)) : (false, _currentOrderEntryPrice.sub(exitPrice).div(_currentOrderEntryPrice));
    }

    /**
    * @dev Updates the entry/exit rules of the bot based on the underlying asset's latest price
    * @param latestPrice Latest price of the bot's underlying asset
    */
    function _updateRules(uint latestPrice) private {
        //Bounded by maximum number of entry rules (from Settings contract)
        for (uint i = 0; i < _entryRules.length; i++)
        {
            IIndicator(_entryRules[i].firstIndicatorAddress).update(latestPrice);
            IIndicator(_entryRules[i].secondIndicatorAddress).update(latestPrice);
        }

        for (uint i = 0; i < _exitRules.length; i++)
        {
            IIndicator(_exitRules[i].firstIndicatorAddress).update(latestPrice);
            IIndicator(_exitRules[i].secondIndicatorAddress).update(latestPrice);
        }
    }

    /**
    * @dev Checks whether all entry rules are met
    * @return bool Whether each entry rule is met
    */
    function _checkEntryRules() private returns (bool) {
        for (uint i = 0; i < _entryRules.length; i++)
        {
            if (!IComparator(_entryRules[i].comparatorAddress).checkConditions())
            {
                return false;
            }
        }

        return true;
    }

    /**
    * @dev Checks whether at least one exit rule is met
    * @return bool Whether at least one exit rule is met
    */
    function _checkExitRules() private returns (bool) {
        for (uint i = 0; i < _exitRules.length; i++)
        {
            if (!IComparator(_exitRules[i].comparatorAddress).checkConditions())
            {
                return true;
            }
        }

        return false;
    }

    /**
    * @dev Given the latest price of the bot's underlying asset, returns whether the profit target is met
    * @param latestPrice Latest price of the bot's underlying asset
    * @return bool Whether the profit target is met
    */
    function _checkProfitTarget(uint latestPrice) private view returns (bool) {
        return (latestPrice > _currentOrderEntryPrice.mul(1 + _profitTarget.div(100)));
    }

    /**
    * @dev Given the latest price of the bot's underlying asset, returns whether the stop loss is met
    * @param latestPrice Latest price of the bot's underlying asset
    * @return bool Whether the stop loss is met
    */
    function _checkStopLoss(uint latestPrice) private view returns (bool) {
        return (latestPrice < _currentOrderEntryPrice.mul(1 - _stopLoss.div(100)));
    }

    /**
    * @dev Generates entry/exit rules based on the parameters of each entry/exit rule
    * @param entryRules Parameters of each entry rule
    * @param exitRules Parameters of each exit rule
    */
    function _generateRules(uint[] memory entryRules, uint[] memory exitRules) internal {

        for (uint i = 0; i < entryRules.length; i++)
        {
            _entryRules.push(_generateRule(entryRules[i]));
        }

        for (uint i = 0; i < exitRules.length; i++)
        {
             _exitRules.push(_generateRule(exitRules[i]));
        }
    }

    /**
    * @dev Generates a Rule based on the given parameters
    * @notice bits 0-124: empty
              bit 125: whether the comparator is default
              bits 126-141: comparator type
              bit 142: whether the first indicator is default
              bits 143-158: first indicator type
              bit 159: whether the second indicator is default
              bits 160-175: second indicator type
              bits 176-215: first indicator parameter
              bits 216-255: second indicator parameter
    * @param rule Parameters of the rule
    * @return Rule The indicators and comparators generated from the rule's parameters
    */
    function _generateRule(uint rule) private returns (Rule memory) {
        bool comparatorIsDefault = ((rule << 125) >> 255) == 1;
        uint comparator = (rule << 126) >> 240;
        bool firstIndicatorIsDefault = ((rule << 142) >> 255) == 1;
        uint firstIndicator = (rule << 143) >> 240;
        bool secondIndicatorIsDefault = ((rule << 159) >> 255) == 1;
        uint secondIndicator = (rule << 160) >> 240;
        uint firstIndicatorParam = (rule << 176) >> 216;
        uint secondIndicatorParam = (rule << 216) >> 216;

        address firstIndicatorAddress = _addBotToIndicator(firstIndicatorIsDefault, firstIndicator, firstIndicatorParam);
        address secondIndicatorAddress = _addBotToIndicator(secondIndicatorIsDefault, secondIndicator, secondIndicatorParam);
        address comparatorAddress = _addBotToComparator(comparatorIsDefault, comparator, firstIndicatorAddress, secondIndicatorAddress);

        require(firstIndicatorAddress != address(0) && secondIndicatorAddress != address(0) && comparatorAddress != address(0), "Invalid address when generating rule");

        return Rule(firstIndicatorAddress, secondIndicatorAddress, comparatorAddress);
    }

    /**
    * @dev Adds trading bot to the indicator
    * @param isDefault Whether indicator is a default indicator
    * @param indicatorIndex Index of indicator in array of available indicators
    * @param indicatorParam Parameter for the indicator
    * @return address Address of the indicator
    */
    function _addBotToIndicator(bool isDefault, uint indicatorIndex, uint indicatorParam) private returns (address) {
        address indicatorAddress = COMPONENTS.getIndicatorFromIndex(isDefault, indicatorIndex);

        IIndicator(indicatorAddress).addTradingBot(indicatorParam);

        return indicatorAddress;
    }

    /**
    * @dev Adds trading bot to the comparator
    * @param isDefault Whether comparator is a default comparator
    * @param comparatorIndex Index of comparator in array of available comparators
    * @param firstIndicatorAddress Address of the first indicator
    * @param secondIndicatorAddress Address of the second indicator
    * @return address Address of the comparator
    */
    function _addBotToComparator(bool isDefault, uint comparatorIndex, address firstIndicatorAddress, address secondIndicatorAddress) private returns (address) {
        require(firstIndicatorAddress != address(0), "Invalid first indicator address");
        require(secondIndicatorAddress != address(0), "Invalid second indicator address");

        address comparatorAddress = COMPONENTS.getComparatorFromIndex(isDefault, comparatorIndex);

        IComparator(comparatorAddress).addTradingBot(firstIndicatorAddress, secondIndicatorAddress);

        return comparatorAddress;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyOracle() {
        require(msg.sender == _oracleAddress, "Only the oracle can call this function");
        _;
    }

    modifier onlyTradingBotRewards() {
        require(msg.sender == ADDRESS_RESOLVER.getContractAddress("TradingBotRewards"), "Only the TradingBotRewards contract can call this function");
        _;
    }

    modifier onlyStrategy() {
        require(ADDRESS_RESOLVER.checkIfStrategyAddressIsValid(msg.sender), "Only the Strategy contract can call this function");
        _;
    }

    /* ========== EVENTS ========== */

    event PlacedOrder(address tradingBotAddress, uint256 timestamp, address underlyingAsset, uint size, uint price, bool orderType);
}
