pragma solidity 0.5.16;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see `ERC20Detailed`.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

pragma solidity 0.5.16;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

interface StakingMaster {
    function calculateUserPercentage(address from) external returns (uint256);
}

contract Pool {
    using SafeMath for uint256;

    address public stakingMaster;
    uint256 public rewardAmount;
    uint256 public rewardBalance;
    address public tokenAddress;

    StakingMaster public stakingInterface;
    IERC20 public ERC20Interface;

    mapping(address => bool) public claimed;

    /**
     *   @param
     *   _stakingMaster contract address of SFUND staking contract
     *   _tokenAddress contract address of the token to be rewarded
     */
    constructor(address _stakingMaster, address _tokenAddress) public {
        require(_stakingMaster != address(0), "Zero staking master address");
        stakingMaster = _stakingMaster;
        stakingInterface = StakingMaster(stakingMaster);
        require(_tokenAddress != address(0), "Zero token address");
        tokenAddress = _tokenAddress;
    }

    /**
     *  Requirements:
     *  `_rewardAmount` rewards to be added to the pool contract
     *  @dev to add rewards to the pool contract
     *  once the allowance is given to this contract for 'rewardAmount' by the user
     */
    function addReward(uint256 _rewardAmount)
        external
        _hasAllowance(msg.sender, _rewardAmount)
        returns (bool)
    {
        require(_rewardAmount > 0, "Zero reward amount");
        address from = msg.sender;
        bool paidReward = _payMe(from, _rewardAmount);
        require(paidReward, "Error adding rewards");
        rewardAmount = rewardAmount.add(_rewardAmount);
        rewardBalance = rewardBalance.add(_rewardAmount);
    }

    /**
     *  @dev for SFUND staking users to claim the pool rewards
     */
    function claim() external returns (bool) {
        address from = msg.sender;
        require(!claimed[from], "Already claimed");
        uint256 percent = stakingInterface.calculateUserPercentage(from);
        require(percent > 0, "No Stakes found");
        uint256 rewardPercent = rewardAmount.mul(percent).div(10000);
        if (rewardPercent >= rewardBalance) {
            rewardPercent = rewardBalance;
        }
        rewardBalance = rewardBalance.sub(rewardPercent);
        require(rewardPercent > 0, "Zero rewards");
        bool paid = _payDirect(from, rewardPercent);
        require(paid, "Error paying rewards to user");
        claimed[from] = true;
        return true;
    }

    function _payMe(address payer, uint256 amount) private returns (bool) {
        return _payTo(payer, address(this), amount);
    }

    function _payTo(
        address allower,
        address receiver,
        uint256 amount
    ) private returns (bool) {
        // Request to transfer amount from the contract to receiver.
        // contract does not own the funds, so the allower must have added allowance to the contract
        // Allower is the original owner.
        ERC20Interface = IERC20(tokenAddress);
        return ERC20Interface.transferFrom(allower, receiver, amount);
    }

    function _payDirect(address to, uint256 amount) private returns (bool) {
        ERC20Interface = IERC20(tokenAddress);
        return ERC20Interface.transfer(to, amount);
    }

    modifier _hasAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        ERC20Interface = IERC20(tokenAddress);
        uint256 ourAllowance = ERC20Interface.allowance(allower, address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        _;
    }
}
