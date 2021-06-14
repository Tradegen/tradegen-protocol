pragma solidity >=0.5.0;

//Inheritance
import './Ownable.sol';

//Interfaces
import './interfaces/IIndicator.sol';
import './interfaces/IComparator.sol';
import './interfaces/IERC20.sol';

//Inheritance
import './interfaces/IComponents.sol';

contract Components is IComponents, Ownable {

    IERC20 private immutable TRADEGEN;
    address private _userManagerAddress;

    address[] public defaultIndicators;
    address[] public defaultComparators;
    address[] public indicators;
    address[] public comparators;

    mapping (address => uint) public indicatorAddressToIndex; //maps to (index + 1); index 0 represents indicator address not valid
    mapping (address => uint) public comparatorAddressToIndex; //maps to (index + 1); index 0 represents comparator address not valid

    mapping (address => uint[]) public userPurchasedIndicators;
    mapping (address => uint[]) public userPurchasedComparators;

    mapping (address => mapping (address => uint)) public indicatorUsers; //maps to (index + 1); index 0 represents indicator not purchased by user
    mapping (address => mapping (address => uint)) public comparatorUsers; //maps to (index + 1); index 0 represents comparator not purchased by user

    constructor(IERC20 baseTradegen, address userManagerAddress) public {
        require(userManagerAddress != address(0), "Invalid user manager address");
        TRADEGEN = baseTradegen;
        _userManagerAddress = userManagerAddress;
    }

    /* ========== VIEWS ========== */

    /**
    * @dev Returns the address of each default indicator
    * @return address[] The addresses of available default indicators
    */
    function getDefaultIndicators() public view override returns (address[] memory) {
        return defaultIndicators;
    }

    /**
    * @dev Returns the address of each custom indicator
    * @return address[] The addresses of available custom indicators
    */
    function getIndicators() public view override returns (address[] memory) {
        return indicators;
    }

    /**
    * @dev Returns the address of each default comparator
    * @return address[] The addresses of available default comparator
    */
    function getDefaultComparators() public view override returns (address[] memory) {
        return defaultComparators;
    }

    /**
    * @dev Returns the address of each custom comparator
    * @return address[] The addresses of available custom comparator
    */
    function getComparators() public view override returns (address[] memory) {
        return comparators;
    }

    /**
    * @dev Returns index of each indicator the user purchased
    * @param user Address of the user
    * @return uint[] The index in indicators array of each indicator the user purchased
    */
    function getUserPurchasedIndicators(address user) public view override returns (uint[] memory) {
        require(user != address(0), "Invalid user address");

        return userPurchasedIndicators[user];
    }

    /**
    * @dev Returns index of each comparator the user purchased
    * @param user Address of the user
    * @return uint[] The index in comparators array of each comparator the user purchased
    */
    function getUserPurchasedComparators(address user) public view override returns (uint[] memory) {
        require(user != address(0), "Invalid user address");

        return userPurchasedComparators[user];
    }

    /**
    * @dev Checks whether the user purchased the given indicator
    * @param user Address of the user
    * @param indicatorIndex Index of the indicator in the indicators array
    * @return bool Whether the user purchased the given indicator
    */
    function checkIfUserPurchasedIndicator(address user, uint indicatorIndex) public view override returns (bool) {
        require(user != address(0), "Invalid user address");
        require(indicatorIndex >= 0 && indicatorIndex < indicators.length, "Indicator index out of range");

        address indicatorAddress = indicators[indicatorIndex];

        return indicatorUsers[indicatorAddress][user] > 0;
    }

    /**
    * @dev Checks whether the user purchased the given comparator
    * @param user Address of the user
    * @param comparatorIndex Index of the comparator in the comparators array
    * @return bool Whether the user purchased the given comparator
    */
    function checkIfUserPurchasedComparator(address user, uint comparatorIndex) public view override returns (bool) {
        require(user != address(0), "Invalid user address");
        require(comparatorIndex >= 0 && comparatorIndex < comparators.length, "Comparators index out of range");

        address comparatorAddress = comparators[comparatorIndex];

        return comparatorUsers[comparatorAddress][user] > 0;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
    * @dev Purchase the given indicator
    * @param indicatorAddress Address of the indicator to purchase
    */
    function buyIndicator(address indicatorAddress) public override {
        require(indicatorAddress != address(0), "Invalid indicator address");
        require(indicatorAddressToIndex[indicatorAddress] > 0, "Invalid indicator address");
        require(indicatorUsers[indicatorAddress][msg.sender] > 0, "Already purchased this indicator");

        (uint price, address developer) = IIndicator(indicatorAddress).getPriceAndDeveloper();

        //Send TGEN payment to indicator's developer; call TradegenERC20.approve() on frontend before sending transaction
        TRADEGEN.transferFrom(msg.sender, developer, price);

        indicatorUsers[indicatorAddress][msg.sender] = indicatorAddressToIndex[indicatorAddress];
        userPurchasedIndicators[msg.sender].push(indicatorAddressToIndex[indicatorAddress] - 1);
    }

    /**
    * @dev Purchase the given comparator
    * @param comparatorAddress Address of the comparator to purchase
    */
    function buyComparator(address comparatorAddress) public override {
        require(comparatorAddress != address(0), "Invalid comparator address");
        require(comparatorAddressToIndex[comparatorAddress] > 0, "Invalid comparator address");
        require(comparatorUsers[comparatorAddress][msg.sender] > 0, "Already purchased this comparator");

        (uint price, address developer) = IComparator(comparatorAddress).getPriceAndDeveloper();

        //Send TGEN payment to comparator's developer; call TradegenERC20.approve() on frontend before sending transaction
        TRADEGEN.transferFrom(msg.sender, developer, price);

        comparatorUsers[comparatorAddress][msg.sender] = comparatorAddressToIndex[comparatorAddress];
        userPurchasedComparators[msg.sender].push(comparatorAddressToIndex[comparatorAddress] - 1);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
    * @dev Adds a new indicator to the platform
    * @param indicatorAddress Address of the contract where the indicator is implemented
    */
    function _addNewIndicator(address indicatorAddress) public override onlyOwner {
        require(indicatorAddress != address(0), "Invalid indicator address");

        indicators.push(indicatorAddress);
        indicatorAddressToIndex[indicatorAddress] = indicators.length;

        emit AddedIndicator(indicatorAddress, indicators.length - 1, block.timestamp);
    }

    /**
    * @dev Adds a new comparator to the platform
    * @param comparatorAddress Address of the contract where the comparator is implemented
    */
    function _addNewComparator(address comparatorAddress) public override onlyOwner {
        require(comparatorAddress != address(0), "Invalid comparator address");

        comparators.push(comparatorAddress);
        comparatorAddressToIndex[comparatorAddress] = comparators.length;

        emit AddedComparator(comparatorAddress, comparators.length - 1, block.timestamp);
    }

    /**
    * @dev Adds default indicators and comparators to the given user
    * @param user Address of user to add default indicators and comparators to
    */
    function _addDefaultComponentsToUser(address user) public override onlyUserManager {
        require(user != address(0), "Invalid user address");

        uint[] memory _userPurchasedIndicators = new uint[](defaultIndicators.length);
        uint[] memory _userPurchasedComparators = new uint[](defaultComparators.length);

        //Add default indicators to the user's array of purchased indicators
        for (uint i = 0; i < defaultIndicators.length; i++)
        {
            _userPurchasedIndicators[i] = indicatorAddressToIndex[defaultIndicators[i]] - 1;
            indicatorUsers[defaultIndicators[i]][user] = indicatorAddressToIndex[defaultIndicators[i]];
        }

        //Add default comparators to the user's array of purchased comparators
        for (uint i = 0; i < defaultComparators.length; i++)
        {
            _userPurchasedComparators[i] = comparatorAddressToIndex[defaultComparators[i]] - 1;
            comparatorUsers[defaultComparators[i]][user] = comparatorAddressToIndex[defaultComparators[i]];
        }

        userPurchasedIndicators[user] = _userPurchasedIndicators;
        userPurchasedComparators[user] = _userPurchasedComparators;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyUserManager() {
        require(msg.sender == _userManagerAddress, "Only the UserManager contract can call this function");
        _;
    }

    /* ========== EVENTS ========== */

    event AddedIndicator(address indicatorAddress, uint indicatorindex, uint timestamp);
    event AddedComparator(address comparatorAddress, uint comparatorindex, uint timestamp);
}