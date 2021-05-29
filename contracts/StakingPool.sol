//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./LPTokenWrapper.sol";
import "./RewardRecipient.sol";

interface IRewardDistributor {
  function transferReward(address to, uint256 value) external;
}

contract StakingPool is LPTokenWrapper, RewardRecipient {
  IERC20 public rewardToken;

  uint256 public rewardRate = 0;
  uint256 public lastUpdateTime;
  uint256 public rewardPerTokenStored;

  mapping(address => uint256) public userRewardPerTokenPaid;
  mapping(address => uint256) public rewards;

  event RewardRateUpdated(uint256 oldRewardRate, uint256 newRewardRate);
  event Staked(address indexed user, uint256 amount);
  event Withdrawn(address indexed user, uint256 amount);
  event RewardPaid(address indexed user, uint256 reward);

  constructor(
    address _lp,
    address _rewardToken,
    address _rewardDistributor
  ) public {
    uni_lp = IERC20(_lp);
    rewardToken = IERC20(_rewardToken);
    rewardDistributor = _rewardDistributor;
  }

  modifier updateReward(address account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = block.timestamp;
    if (account != address(0)) {
      rewards[account] = earned(account);
      userRewardPerTokenPaid[account] = rewardPerTokenStored;
    }
    _;
  }

  function rewardPerToken() public view returns (uint256) {
    if (totalSupply() == 0) {
      return rewardPerTokenStored;
    }
    return
      rewardPerTokenStored.add(
        block.timestamp.sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(
          totalSupply()
        )
      );
  }

  function earned(address account) public view returns (uint256) {
    return
      balanceOf(account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
        .div(1e18)
        .add(rewards[account]);
  }

  // stake visibility is public as overriding LPTokenWrapper's stake() function
  function stake(uint256 amount) public override updateReward(msg.sender) {
    require(amount > 0, "Cannot stake 0");
    super.stake(amount);
    emit Staked(msg.sender, amount);
  }

  function withdraw(uint256 amount) public override updateReward(msg.sender) {
    require(amount > 0, "Cannot withdraw 0");
    super.withdraw(amount);
    emit Withdrawn(msg.sender, amount);
  }

  function exit() external {
    withdraw(balanceOf(msg.sender));
    getReward();
  }

  function getReward() public updateReward(msg.sender) {
    uint256 reward = rewards[msg.sender];
    if (reward > 0) {
      rewards[msg.sender] = 0;
      IRewardDistributor(rewardDistributor).transferReward(msg.sender, reward);
      emit RewardPaid(msg.sender, reward);
    }
  }

  function setRewardRate(uint256 _rewardRate)
    external
    override
    onlyRewardDistributor
    updateReward(address(0))
  {
    uint256 _oldRewardRate = rewardRate;
    rewardRate = _rewardRate;
    lastUpdateTime = block.timestamp;
    emit RewardRateUpdated(_oldRewardRate, _rewardRate);
  }

  // This function allows governance to take unsupported tokens out of the
  // contract, since this one exists longer than the other pools.
  // This is in an effort to make someone whole, should they seriously
  // mess up. There is no guarantee governance will vote to return these.
  // It also allows for removal of airdropped tokens.
  function rescueTokens(
    IERC20 _token,
    uint256 amount,
    address to
  ) external {
    // only gov
    require(msg.sender == owner(), "!governance");
    // cant take staked asset
    require(_token != uni_lp, "uni_lp");
    // cant take reward asset
    require(_token != rewardToken, "rewardToken");

    // transfer to
    _token.transfer(to, amount);
  }
}
