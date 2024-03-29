// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

// Libraries.
import "./openzeppelin-solidity/SafeMath.sol";
import "./openzeppelin-solidity/SafeERC20.sol";

// Inheritance.
import "./Ownable.sol";
import './interfaces/ITradegenStakingEscrow.sol';

// Internal references.
import "./interfaces/IAddressResolver.sol";

contract TradegenLPStakingEscrow is Ownable, ITradegenStakingEscrow {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    IAddressResolver public immutable ADDRESS_RESOLVER;

    // TGEN.
    IERC20 public immutable REWARD_TOKEN;

    constructor(IAddressResolver _addressResolver, address _rewardToken) Ownable() {
        ADDRESS_RESOLVER = _addressResolver;
        REWARD_TOKEN = IERC20(_rewardToken);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
    * @notice Withdraws the given amount of tokens from escrow and transfer them to the given user.
    * @dev Transaction will revert if the given amount exceeds the user's balance.
    * @param user Address of the user.
    * @param amount Amount of tokens to withdraw.
    */
    function claimStakingRewards(address user, uint amount) external override onlyStakingRewards {        
        require(amount > 0, "TradegenLPStakingEscrow: No staking rewards to claim.");
        require(REWARD_TOKEN.balanceOf(address(this)) >= amount, "TradegenLPStakingEscrow: Not enough TGEN in escrow.");
        
        REWARD_TOKEN.safeTransfer(user, amount);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyStakingRewards() {
        address stakingRewardsAddress = ADDRESS_RESOLVER.getContractAddress("TradegenLPStakingRewards");

        require(msg.sender == stakingRewardsAddress, "TradegenLPStakingEscrow: Only the TradegenLPStakingRewards contract can call this function.");
        _;
    }
}