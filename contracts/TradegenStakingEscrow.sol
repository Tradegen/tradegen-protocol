pragma solidity >=0.5.0;

//Libraries
import './libraries/SafeMath.sol';

// Inheritance
import "./Ownable.sol";

// Internal references
import "./interfaces/IERC20.sol";
import "./interfaces/IAddressResolver.sol";

contract TradegenStakingEscrow is Ownable {
    using SafeMath for uint;

    IAddressResolver public immutable ADDRESS_RESOLVER;

    constructor(IAddressResolver _addressResolver) public Ownable() {
        ADDRESS_RESOLVER = _addressResolver;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function claimStakingRewards(address user, uint amount) public onlyStakingRewards {
        address tradegenAddress = ADDRESS_RESOLVER.getContractAddress("BaseTradegen");
        
        require(amount > 0, "No staking rewards to claim");
        require(IERC20(tradegenAddress).balanceOf(address(this)) >= amount, "Not enough TGEN in escrow");
        
        
        IERC20(tradegenAddress).transfer(user, amount);
    }

    /* ========== MODIFIERS ========== */

    modifier onlyStakingRewards() {
        address stakingRewardsAddress = ADDRESS_RESOLVER.getContractAddress("TradegenStakingRewards");

        require(msg.sender == stakingRewardsAddress, "Only the TradegenStakingRewards contract can call this function");
        _;
    }
}