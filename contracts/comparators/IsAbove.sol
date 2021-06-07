pragma solidity >=0.5.0;

import '../interfaces/IIndicator.sol';
import '../interfaces/IComparator.sol';

contract IsAbove is IComparator {

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

        uint[] memory firstIndicatorPriceHistory = IIndicator(tradingBotState.firstIndicatorAddress).getValue(tradingBotAddress);
        uint[] memory secondIndicatorPriceHistory = IIndicator(tradingBotState.secondIndicatorAddress).getValue(tradingBotAddress);

        if (firstIndicatorPriceHistory.length == 0 || secondIndicatorPriceHistory.length == 0)
        {
            return false;
        }

        return (firstIndicatorPriceHistory[firstIndicatorPriceHistory.length - 1] > secondIndicatorPriceHistory[secondIndicatorPriceHistory.length - 1]);
    }
}