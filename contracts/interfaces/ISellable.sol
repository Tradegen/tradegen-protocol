// SPDX-License-Identifier: MIT

pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

interface ISellable {
    /**
    * @notice Transfers tokens from seller to buyer.
    * @param from Address of the seller.
    * @param to Address of the buyer.
    * @param tokenClass The class of the asset's token.
    * @param numberOfTokens Number of tokens to purchase.
    */
    function transfer(address from, address to, uint tokenClass, uint numberOfTokens) external returns(bool);

    /**
    * @notice Returns the number of tokens the user has for the given token class.
    * @dev The balance includes tokens the user has for sale.
    * @param user Address of the user.
    * @param tokenClass The class of the asset's token.
    * @return uint Number of tokens the user has for the given token class.
    */
    function balanceOf(address user, uint tokenClass) external view returns(uint);

    /**
    * @notice Returns the total number of tokens the user has across token classes.
    * @dev The balance includes tokens the user has for sale.
    * @param user Address of the user.
    * @return uint Total number of tokens the user has.
    */
    function balance(address user) external view returns(uint);

    /**
    * @notice Returns the number of tokens available for each class.
    * @return (uint, uint, uint, uint) Number of available C1, C2, C3, and C4 tokens.
    */
    function getAvailableTokensPerClass() external view returns(uint, uint, uint, uint);

    /**
    * @notice Given the address of a user, returns the number of tokens the user has for each class.
    * @param user Address of the user.
    * @return (uint, uint, uint, uint) Number of available C1, C2, C3, and C4 tokens.
    */
    function getTokenBalancePerClass(address user) external view returns(uint, uint, uint, uint);
}