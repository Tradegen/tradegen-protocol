pragma solidity >=0.5.0;

import '../interfaces/IIndicator.sol';

contract Down is IIndicator {

    function getName() public pure override returns (string memory) {
        return "Down";
    }

    function addTradingBot(address tradingBotAddress, uint param) public pure override {}

    function update(address tradingBotAddress, uint latestPrice) public override {}   

    function getValue(address tradingBotAddress) public pure override returns (uint[] memory) {
        uint[] memory temp = new uint[](1);
        temp[0] = 0;
        return temp;
    }

    function getHistory(address tradingBotAddress) public pure override returns (uint[] memory) {
        return new uint[](0);
    }
}