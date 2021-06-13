pragma solidity >=0.5.0;

interface ISettings {

    struct OracleData {
        address oracleAddress;
        string oracleName;
    }
    
    /**
    * @dev Given the name of a parameter, returns the value of the parameter
    * @param parameter The name of the parameter to get value for
    * @return uint The value of the given parameter
    */
    function getParameterValue(string memory parameter) external view returns(uint);

    /**
    * @dev Returns the addresses of supported currencies for trading
    * @return address[] An array of addresses of supported currencies
    */
    function getAvailableCurrencies() external view returns(address[] memory);

    /**
    * @dev Given the address of a currency, returns the currency's symbol
    * @param currencyKey The address of the currency
    * @return string The currency symbol
    */
    function getCurrencySymbol(address currencyKey) external view returns(string memory);

    /**
    * @dev Returns the addresses of supported oracle APIs
    * @return address[] An array of oracle API addresses
    */
    function getOracleAPIAddresses() external view returns(address[] memory);

    /**
    * @dev Given the address of an oracle API, returns the name of the oracle API
    * @param oracleAddress The address of the oracle API
    * @return string The oracle API name
    */
    function getOracleAPIName(address oracleAddress) external view returns(string memory);

    /**
    * @dev Updates the address for the given contract; meant to be called by Settings contract owner
    * @param parameter The name of the parameter to change
    * @param newValue The new value of the given parameter
    */
    function setParameterValue(string memory parameter, uint newValue) external;

    /**
    * @dev Updates the address of the given currency
    * @param currencySymbol The currency symbol
    * @param newCurrencyKey The new address for the given currency
    */
    function updateCurrencyKey(string memory currencySymbol, address newCurrencyKey) external;

    /**
    * @dev Adds a new tradable currency to the platform
    * @param currencySymbol The symbol of the currency to add
    * @param currencyKey The address of the currency to add
    */
    function addCurrencyKey(string memory currencySymbol, address currencyKey) external;

    /**
    * @dev Updates the address of a given oracle API
    * @param oldOracleAddress The address of the oracle API to update
    * @param newOracleAddress The new address of the given oracle API
    */
    function updateOracleAPIAddress(address oldOracleAddress, address newOracleAddress) external;

    /**
    * @dev Adds a new oracle API to the platform
    * @param name The name of the oracle API
    * @param oracleAddress The address of the oracle API
    */
    function addOracleAPIAddress(string memory name, address oracleAddress) external;
}