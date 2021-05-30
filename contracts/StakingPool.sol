//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./Ownable.sol";
import "./LPTokenWrapper.sol";

contract StakingPool is Ownable, LPTokenWrapper {
  using SafeERC20 for IERC20;

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

  constructor(address _lp, address _rewardToken) public {
    __Ownable_init();
    uni_lp = IERC20(_lp);
    rewardToken = IERC20(_rewardToken);
  }

  modifier updateReward(address _account) {
    rewardPerTokenStored = rewardPerToken();
    lastUpdateTime = block.timestamp;
    if (_account != address(0)) {
      rewards[_account] = earned(_account);
      userRewardPerTokenPaid[_account] = rewardPerTokenStored;
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

  function earned(address _account) public view returns (uint256) {
    return
      balanceOf(_account)
        .mul(rewardPerToken().sub(userRewardPerTokenPaid[_account]))
        .div(1e18)
        .add(rewards[_account]);
  }

  // stake visibility is public as overriding LPTokenWrapper's stake() function
  function stake(uint256 _amount) public override updateReward(msg.sender) {
    require(_amount > 0, "Cannot stake 0");
    super.stake(_amount);
    emit Staked(msg.sender, _amount);
  }

  function withdraw(uint256 _amount) public override updateReward(msg.sender) {
    require(_amount > 0, "Cannot withdraw 0");
    super.withdraw(_amount);
    emit Withdrawn(msg.sender, _amount);
  }

  function exit() external {
    withdraw(balanceOf(msg.sender));
    getReward();
  }

  function getReward() public updateReward(msg.sender) {
    uint256 _reward = rewards[msg.sender];
    if (_reward > 0) {
      rewards[msg.sender] = 0;
      rewardToken.safeTransferFrom(owner, msg.sender, _reward);
      emit RewardPaid(msg.sender, _reward);
    }
  }

  function setRewardRate(uint256 _rewardRate)
    external
    onlyOwner
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
    uint256 _amount,
    address _to
  ) external onlyOwner {
    // cant take staked asset
    require(_token != uni_lp, "uni_lp");
    // cant take reward asset
    require(_token != rewardToken, "rewardToken");

    // transfer _to
    _token.transfer(_to, _amount);
  }
}
