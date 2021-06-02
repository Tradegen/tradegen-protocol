pragma solidity >=0.5.0;

//libraries
import './libraries/SafeMath.sol';
import './libraries/Ownable.sol';

contract StrategyManager {
    using SafeMath for uint;

    address[] public strategies; // stores contract address of each published strategy
    mapping (address => uint[]) public userToPublishedStrategies; //stores indexes of user's published strategies
    mapping (address => uint[]) public userToPositions; //stores index of user's positions (strategies);
    mapping (address => uint) public addressToIndex; // maps to (index + 1); index 0 represents strategy not found

    /* ========== INTERNAL FUNCTIONS ========== */

    function _getUserPublishedStrategies(address _user) internal view returns(address[] memory) {
        uint[] memory userPublishedStrategyIndexes = userToPublishedStrategies[_user];
        address[] memory userPublishedStrategies = new address[](userPublishedStrategyIndexes.length);

        for (uint i = 0; i < userPublishedStrategyIndexes.length; i++)
        {
            userPublishedStrategies[i] = strategies[userPublishedStrategyIndexes[i]];
        }

        return userPublishedStrategies;
    }

    function _getUserPositions(address _user) internal view returns(address[] memory) {
        uint[] memory userPositionIndexes = userToPositions[_user];
        address[] memory userPositions = new address[](userPositionIndexes.length);

        for (uint i = 0; i < userPositionIndexes.length; i++)
        {
            userPositions[i] = strategies[userPositionIndexes[i]];
        }

        return userPositions;
    }

    function _addPosition(address _user, address _strategyAddress) internal isValidStrategyAddress(_strategyAddress) {
        userToPositions[_user].push(addressToIndex[_strategyAddress] - 1);
    }

    function _removePosition(address _user, address _strategyAddress) internal isValidStrategyAddress(_strategyAddress) {
        uint positionIndex;
        uint strategyIndex = addressToIndex[_strategyAddress];

        for (positionIndex = 0; positionIndex < userToPositions[_user].length; positionIndex++)
        {
            if (positionIndex == strategyIndex)
            {
                break;
            }
        }

        require (positionIndex < userToPositions[_user].length, "Position not found");

        userToPositions[_user][positionIndex] = userToPositions[_user][userToPositions[_user].length - 1];
        delete userToPositions[_user][userToPositions[_user].length - 1];
    }

    //TODO
    /*function publishStrategy() internal returns(address) {
        return userToDevelopedStrategies[_user];
    }*/

    /* ========== MODIFIERS ========== */

    modifier isValidStrategyAddress(address _strategyAddress) {
        require(addressToIndex[_strategyAddress] > 0, "Strategy address not found");
        _;
    }

    /* ========== EVENTS ========== */

    event PublishedStrategy();
}