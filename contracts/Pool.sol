pragma solidity >=0.5.0;

import './adapters/interfaces/IBaseUbeswapAdapter.sol';

import './interfaces/IERC20.sol';
import './interfaces/IPool.sol';
import './interfaces/IUserPoolFarm.sol';

import './libraries/SafeMath.sol';

import './AddressResolver.sol';
import './Settings.sol';
import './TradegenERC20.sol';

contract Pool is IPool, AddressResolver {
    using SafeMath for uint;

    IUserPoolFarm public immutable FARM;

    string public _name;
    uint public _supply;
    address public _manager;
    uint public _performanceFee; //expressed as %

    address[] public _positionKeys;
    uint public cUSDdebt;
    uint public TGENdebt;

    mapping (address => uint) public balanceOf;
    mapping (address => uint) public investorToIndex; //maps to (index + 1) in investors array; index 0 represents investor not found
    address[] public investors;

    constructor(string memory name, uint performanceFee, address manager, IUserPoolFarm userPoolFarm) public onlyPoolManager(msg.sender) {
        _name = name;
        _manager = manager;
        _performanceFee = performanceFee;
        FARM = userPoolFarm;
    }

    /* ========== VIEWS ========== */

    function getPoolName() public view override returns (string memory) {
        return _name;
    }

    function getManagerAddress() public view override returns (address) {
        return _manager;
    }

    function getInvestors() public view override returns (InvestorAndBalance[] memory) {
        InvestorAndBalance[] memory temp = new InvestorAndBalance[](investors.length);

        for (uint i = 0; i < investors.length; i++)
        {
            temp[i] = InvestorAndBalance(investors[i], balanceOf[investors[i]]);
        }

        return temp;
    }

    function getPositionsAndTotal() public view override returns (PositionKeyAndBalance[] memory, uint) {
        PositionKeyAndBalance[] memory temp = new PositionKeyAndBalance[](_positionKeys.length);
        uint sum = 0;

        for (uint i = 0; i < _positionKeys.length; i++)
        {
            uint positionBalance = IERC20(_positionKeys[i]).balanceOf(address(this));
            temp[i] = PositionKeyAndBalance(_positionKeys[i], positionBalance);
            sum.add(positionBalance);
        }

        return (temp, sum);
    }

    function getAvailableFunds() public view override returns (uint) {
        return IERC20(Settings(getSettingsAddress()).getStableCurrencyAddress()).balanceOf(address(this));
    }

    function getPoolBalance() public view override returns (uint) {
        (, uint positionBalance) = getPositionsAndTotal();
        uint availableFunds = getAvailableFunds();
        
        return availableFunds.add(positionBalance);
    }

    function getUserBalance(address user) public view override returns (uint) {
        require(user != address(0), "Invalid address");

        uint poolBalance = getPoolBalance();

        return poolBalance.mul(balanceOf[user]).div(_supply);
    }

    function getUserTokenBalance(address user) public view override returns (uint) {
        require(user != address(0), "Invalid user address");

        return balanceOf[user];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function deposit(uint amount) external override {
        require(amount > 0, "Deposit must be greater than 0");

        //add user to pool's investors
        if (balanceOf[msg.sender] == 0)
        {
            investors.push(msg.sender);
            investorToIndex[msg.sender] = investors.length;
        }

        IERC20(Settings(getSettingsAddress()).getStableCurrencyAddress()).transferFrom(msg.sender, address(this), amount);
        balanceOf[msg.sender].add(amount); //add 1 LP token per cUSD
        _supply.add(amount);

        //settle debt
        _settleDebt(amount);

        emit DepositedFundsIntoPool(msg.sender, address(this), amount, block.timestamp);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function withdraw(address user, uint amount) public override onlyPoolProxy(msg.sender) {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Withdrawal must be greater than 0");

        uint userBalance = getUserBalance(user);
        uint numberOfLPTokensStaked = FARM.balanceOf(user, address(this));
        uint availableTokensToWithdraw = userBalance.sub(numberOfLPTokensStaked);

        require(availableTokensToWithdraw >= amount, "Not enough funds");

        uint poolBalance = getPoolBalance();
        uint numberOfLPTokens = amount.mul(poolBalance).div(_supply);
        uint TGENtoUSD = IBaseUbeswapAdapter(getBaseUbeswapAdapterAddress()).getPrice(Settings(getSettingsAddress()).getBaseTradegenAddress());
        uint TGENequivalent = amount.mul(TGENtoUSD);
        uint fee = (userBalance > balanceOf[user]) ? _payPerformanceFee(user, userBalance, amount, TGENtoUSD) : 0;

        cUSDdebt.add(amount);
        TGENdebt.add(TGENequivalent);
        balanceOf[user].sub(numberOfLPTokens);
        _supply.sub(numberOfLPTokens);

        //remove user from pool's investors user has no funds left in pool
        if (balanceOf[user] == 0)
        {
            uint index = investorToIndex[user];
            address lastInvestor = investors[investors.length - 1];
            investorToIndex[lastInvestor] = index;
            investors[index - 1] = lastInvestor;
            investors.pop();
            delete investorToIndex[user];
        }

        TradegenERC20(getBaseTradegenAddress()).sendRewards(user, TGENequivalent.sub(fee));

        emit WithdrewFundsFromPool(msg.sender, address(this), amount, block.timestamp);
    }

    function placeOrder(address currencyKey, bool buyOrSell, uint numberOfTokens) external override onlyManager() {
        require(numberOfTokens > 0, "Number of tokens must be greater than 0");
        require(currencyKey != address(0), "Invalid currency key");
        require(Settings(getSettingsAddress()).checkIfCurrencyIsAvailable(currencyKey), "Currency key is not available");

        uint tokenToUSD = IBaseUbeswapAdapter(getBaseUbeswapAdapterAddress()).getPrice(currencyKey);
        address stableCoinAddress = Settings(getSettingsAddress()).getStableCurrencyAddress();
        uint numberOfTokensReceived;

        //buying
        if (buyOrSell)
        {
            require(cUSDdebt == 0, "Need to settle debt before making an opening trade");
            require(getAvailableFunds() >= numberOfTokens.mul(tokenToUSD), "Not enough funds");

            uint amountInUSD = numberOfTokens.div(tokenToUSD);
            uint minAmountOut = numberOfTokens.mul(98).div(100); //max slippage 2%

            numberOfTokensReceived = IBaseUbeswapAdapter(getBaseUbeswapAdapterAddress()).swapFromPool(stableCoinAddress, currencyKey, amountInUSD, minAmountOut);
        }
        //selling
        else
        {
            uint positionIndex;
            for (positionIndex = 0; positionIndex < _positionKeys.length; positionIndex++)
            {
                if (currencyKey == _positionKeys[positionIndex])
                {
                    break;
                }
            }

            require(positionIndex < _positionKeys.length, "Don't have a position in this currency");
            require(IERC20(currencyKey).balanceOf(msg.sender) >= numberOfTokens, "Not enough tokens in this currency");

            _settleDebt(numberOfTokens.mul(tokenToUSD));

            uint amountInUSD = numberOfTokens.mul(tokenToUSD);
            uint minAmountOut = amountInUSD.mul(98).div(100); //max slippage 2%

            numberOfTokensReceived = IBaseUbeswapAdapter(getBaseUbeswapAdapterAddress()).swapFromPool(currencyKey, stableCoinAddress, numberOfTokens, minAmountOut);

            //remove position key if no funds left in currency
            if (IERC20(currencyKey).balanceOf(msg.sender) == 0)
            {
                _positionKeys[positionIndex] = _positionKeys[_positionKeys.length - 1];
                _positionKeys.pop();
            }
        }

        emit PlacedOrder(address(this), currencyKey, buyOrSell, numberOfTokens, numberOfTokensReceived, block.timestamp);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _settleDebt(uint amount) internal {
        require(amount > 0, "Amount must be greater than 0");

        if (cUSDdebt > 0)
        {
            if (amount >= cUSDdebt)
            {
                cUSDdebt = 0;
                TGENdebt = 0;
            }
            else
            {
                uint TGENdebtReduction = amount.mul(TGENdebt).div(cUSDdebt);
                cUSDdebt.sub(amount);
                TGENdebt.sub(TGENdebtReduction);
            }
        }
    }

    function _payPerformanceFee(address user, uint userBalance, uint amount, uint exchangeRate) internal returns (uint) {
        uint profit = userBalance.sub(balanceOf[user]);
        uint ratio = amount.mul(profit).div(userBalance);
        uint fee = ratio.mul(exchangeRate).mul(_performanceFee).div(100);

        TradegenERC20(getBaseTradegenAddress()).sendRewards(_manager, fee);

        emit PaidPerformanceFee(user, address(this), fee, block.timestamp);

        return fee;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyManager() {
        require(msg.sender == _manager, "Only manager can call this function");
        _;
    }

    /* ========== EVENTS ========== */

    event DepositedFundsIntoPool(address indexed user, address indexed poolAddress, uint amount, uint timestamp);
    event WithdrewFundsFromPool(address indexed user, address indexed poolAddress, uint amount, uint timestamp);
    event PaidPerformanceFee(address indexed user, address indexed poolAddress, uint amount, uint timestamp);
    event PlacedOrder(address indexed poolAddress, address indexed currencyKey, bool buyOrSell, uint numberOfTokensSwapped, uint numberOfTokensReceived, uint timestamp);
}