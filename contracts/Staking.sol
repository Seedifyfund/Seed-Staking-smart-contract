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

// File: openzeppelin-solidity/contracts/math/SafeMath.sol

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

pragma solidity 0.5.16;

contract Staking {
    using SafeMath for uint256;

    address public tokenAddress;
    uint256 public totalStaked;
    uint256 public startBlock;
    // uint256 public incBlock; //local testing purpose only
    address public thisGuy;

    IERC20 public ERC20Interface;

    /**
     *  @dev Struct to store user staking data.
     */

    struct Deposit {
        uint256 depositAmount;
        uint256 depositBlock;
        uint256 prevStakingValue;
    }

    mapping(address => Deposit) private userDeposit;
    mapping(address => bool) public staked;

    /**
     *  @dev Emitted when user stakes 'amount' value of tokens
     */
    event Staked(address from, uint256 amount, address token);

    /**
     *  @dev Emitted when user withdraws his stakings
     */
    event Withdraw(address from, uint256 amount, address token);

    /**
     *   @param
     *   _tokenAddress contract address of the token
     *   _epochStartBlock starting block of staking
     */
    constructor(address _tokenAddress, uint256 _epochStartBlock) public {
        require(_tokenAddress != address(0), "Zero token address");
        tokenAddress = _tokenAddress;
        require(_epochStartBlock > block.number, "Invalid start block");
        startBlock = _epochStartBlock;
        thisGuy = address(this);
    }

    /**
     *  Requirements:
     *  `from` User wallet address
     *  @dev returns user staking data
     */
    function userDeposits(address from)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        if (staked[from]) {
            return (
                userDeposit[from].depositAmount,
                userDeposit[from].depositBlock,
                userDeposit[from].prevStakingValue
            );
        }
    }

    /**
     *  Requirements:
     *  `amount` Amount to be staked
     /**
     *  @dev to stake 'amount' value of tokens 
     *  once the user has given allowance to the staking contract
     */
    function stake(uint256 amount)
        external
        _hasAllowance(msg.sender, amount)
        returns (bool)
    {
        require(block.number > startBlock, "Wrong time to invest");
        require(amount > 0, "Zero stake amount");
        address from = msg.sender;
        return (_stake(from, amount));
    }

    function _stake(address from, uint256 amount) private returns (bool) {
        if (!staked[from]) {
            if (!_payMe(from, amount)) {
                return false;
            }
            userDeposit[from] = Deposit(amount, block.number, 0);
            staked[from] = true;
        } else {
            if (!_payMe(from, amount)) {
                return false;
            }
            uint256 newAmount = userDeposit[from].depositAmount.add(amount);
            uint256 currentStakingValue = calculateStakeValue(from);
            userDeposit[from] = Deposit(
                newAmount,
                block.number,
                currentStakingValue
            );
        }

        totalStaked = totalStaked.add(amount);

        if (staked[thisGuy]) {
            uint256 contractStakingValue = calculateStakeValue(thisGuy);
            uint256 newContractAmount =
                userDeposit[thisGuy].depositAmount.add(amount);
            userDeposit[thisGuy] = Deposit(
                newContractAmount,
                block.number,
                contractStakingValue
            );
        } else {
            uint256 newContractAmount =
                userDeposit[thisGuy].depositAmount += amount;
            userDeposit[thisGuy] = Deposit(newContractAmount, block.number, 0);
            staked[thisGuy] = true;
        }

        emit Staked(from, amount, tokenAddress);

        return true;
    }

    /**
     *  Requirements:
     *  `from` User wallet address
     * @dev to calculate the staking value based on user staked 'amount'
     */
    function calculateStakeValue(address from) public view returns (uint256) {
        if (staked[from]) {
            uint256 noOfBlocks =
                block.number.sub(userDeposit[from].depositBlock);
            uint256 value = noOfBlocks.mul(userDeposit[from].depositAmount);
            return (value.add(userDeposit[from].prevStakingValue));
        }
    }

    /**
     *  Requirements:
     *  `from` User wallet address
     * @dev to calculate the user percentage based on user staked 'amount'
     */
    function calculateUserPercentage(address from)
        external
        view
        returns (uint256)
    {
        if (staked[from]) {
            return (
                calculateStakeValue(from).mul(10000).div(
                    calculateStakeValue(thisGuy)
                )
            );
        }
    }

    /**
     *  Requirements:
     *  `amount` Amount to be withdrawn
    /**
     * @dev to withdraw user stakings after the lock period ends.
     */
    function withdraw(uint256 amount) external returns (bool) {
        address from = msg.sender;
        require(
            amount <= userDeposit[from].depositAmount,
            "Insufficient stake"
        );
        return (_withdraw(from, amount));
    }

    function _withdraw(address from, uint256 amount) private returns (bool) {
        uint256 stakingValue = calculateStakeValue(from);
        uint256 newAmount = userDeposit[from].depositAmount.sub(amount);
        userDeposit[from] = Deposit(newAmount, block.number, stakingValue);
        totalStaked = totalStaked.sub(amount);
        uint256 contractAmount = userDeposit[thisGuy].depositAmount.sub(amount);
        uint256 contractStakingValue = calculateStakeValue(thisGuy);
        userDeposit[thisGuy] = Deposit(
            contractAmount,
            block.number,
            contractStakingValue
        );
        bool paid = _payDirect(from, amount);
        require(paid, "Error paying");

        emit Withdraw(from, amount, tokenAddress);
        return true;
    }

    // function currentBlock() public view returns (uint256) {
    //     return block.number; //for local testing purpose only
    // }

    // function increaseBlock() public {
    //     incBlock++; //for local testing purpose only
    // }

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
