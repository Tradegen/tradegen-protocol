pragma solidity >=0.5.0;

import '../interfaces/IIndicator.sol';
import '../interfaces/IComparator.sol';

import '../libraries/SafeMath.sol';

contract RiseByAtLeast is IComparator {
    using SafeMath for uint;

    struct State {
        address firstIndicatorAddress;
        address secondIndicatorAddress;
    }

    function addTradingBot(address tradingBotAddress, address firstIndicatorAddress, address secondIndicatorAddress) public override {
        require(tradingBotAddress != address(0), "Invalid trading bot address");
        require(firstIndicatorAddress != address(0), "Invalid first indicator address");
        require(secondIndicatorAddress != address(0), "Invalid second indicator address");
        require(_tradingBotStates[tradingBotAddress].firstIndicatorAddress == address(0), "Trading bot already exists");

        _tradingBotStates[tradingBotAddress] = State(firstIndicatorAddress, secondIndicatorAddress);
    }

    mapping (address => State) private _tradingBotStates;

    function checkConditions(address tradingBotAddress) public view override returns (bool) {
        require(tradingBotAddress != address(0), "Invalid trading bot address");

        State storage tradingBotState = _tradingBotStates[tradingBotAddress];

        uint[] memory firstIndicatorHistory = IIndicator(tradingBotState.firstIndicatorAddress).getValue(tradingBotAddress);
        uint[] memory secondIndicatorHistory = IIndicator(tradingBotState.secondIndicatorAddress).getValue(tradingBotAddress);

        if (firstIndicatorHistory.length == 0)
        {
            return false;
        }

        //check if indicator fell in value
        if (firstIndicatorHistory[firstIndicatorHistory.length] <= firstIndicatorHistory[0])
        {
            return false;
        }

        uint percentRise = firstIndicatorHistory[firstIndicatorHistory.length - 1].div(firstIndicatorHistory[0]);
        percentRise = percentRise.sub(1);
        percentRise = percentRise.mul(100);
        return (percentRise >= secondIndicatorHistory[0]);
    }
}