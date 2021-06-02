pragma solidity >=0.5.0;

import '../interfaces/IIndicator.sol';

contract Interval is IIndicator {
    uint public currentValue;
    uint[] public history;

    constructor(uint interval) public {
        currentValue = interval;
        history.push(interval);
    }

    function getName() public pure override returns (string memory) {
        return "Interval";
    }

    function update(uint latestPrice) public override {}   

    function getValue() public view override returns (uint[] memory) {
        uint[] memory temp = new uint[](1);
        temp[0] = currentValue;
        return temp;
    }

    function getHistory() public view override returns (uint[] memory) {
        return history;
    }
}