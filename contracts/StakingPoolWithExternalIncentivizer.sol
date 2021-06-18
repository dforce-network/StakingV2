// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./StakingPool.sol";

contract StakingPoolWithExternalIncentivizer is StakingPool {
  using SafeERC20 for IERC20;

  address public externalIncentivizer;
  IERC20 public externalRewardToken;

  uint256 public externalRewardStored;
  uint256 public externalRewardClaimed;

  uint256 public externalRewardPerTokenStored;

  mapping(address => uint256) public userExternalRewardPerTokenPaid;
  mapping(address => uint256) public externalRewards;

  event ExternalRewardPaid(address indexed user, uint256 reward);

  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime,
    address _externalIncentivizer
  ) public StakingPool(_lp, _rewardToken, _startTime) {
    externalIncentivizer = _externalIncentivizer;
    externalRewardToken = StakingPool(externalIncentivizer).rewardToken();

    IERC20(uni_lp).safeApprove(externalIncentivizer, uint256(-1));
  }

  modifier updateExternalReward(address _account) {
    externalRewardPerTokenStored = externalRewardPerToken();
    externalRewardStored = externalReward();
    if (_account != address(0)) {
      externalRewards[_account] = externalEarned(_account);
      userExternalRewardPerTokenPaid[_account] = externalRewardPerTokenStored;
    }
    _;
  }

  function externalReward() public view returns (uint256) {
    return
      externalRewardClaimed.add(
        StakingPool(externalIncentivizer).earned(address(this))
      );
  }

  function externalRewardPerToken() public view returns (uint256) {
    if (totalSupply() == 0) {
      return externalRewardPerTokenStored;
    }

    return
      externalRewardPerTokenStored.add(
        externalReward().sub(externalRewardStored).mul(1e18).div(totalSupply())
      );
  }

  function externalEarned(address _account) public view returns (uint256) {
    return
      balanceOf(_account)
        .mul(
        externalRewardPerToken().sub(userExternalRewardPerTokenPaid[_account])
      )
        .div(1e18)
        .add(externalRewards[_account]);
  }

  // stake visibility is public as overriding LPTokenWrapper's stake() function
  function stake(uint256 _amount)
    public
    override
    updateExternalReward(msg.sender)
  {
    super.stake(_amount);

    // Staking to external pool
    StakingPool(externalIncentivizer).stake(_amount);
  }

  function withdraw(uint256 _amount)
    public
    override
    updateExternalReward(msg.sender)
  {
    // Withdraw from external pool
    StakingPool(externalIncentivizer).withdraw(_amount);

    super.withdraw(_amount);
  }

  function exit() external override {
    withdraw(balanceOf(msg.sender));
    getReward();
  }

  function getExternalReward() internal {
    uint256 balanceBefore = externalRewardToken.balanceOf(address(this));

    StakingPool(externalIncentivizer).getReward();

    uint256 balanceAfter = externalRewardToken.balanceOf(address(this));
    externalRewardClaimed = externalRewardClaimed.add(
      balanceAfter.sub(balanceBefore)
    );
  }

  function getReward() public override updateExternalReward(msg.sender) {
    super.getReward();

    // Claim reward from external incentivizer
    getExternalReward();

    uint256 _externalReward = externalRewards[msg.sender];
    if (_externalReward > 0) {
      externalRewards[msg.sender] = 0;
      externalRewardToken.safeTransfer(msg.sender, _externalReward);
      emit ExternalRewardPaid(msg.sender, _externalReward);
    }
  }
}
