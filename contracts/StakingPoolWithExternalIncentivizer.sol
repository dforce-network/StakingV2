// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./StakingPool.sol";

import "hardhat/console.sol";

contract StakingPoolWithExternalIncentivizer is StakingPool {
  using SafeERC20 for IERC20;

  address public externalIncentivizer;

  uint256 public externalRewardStored;
  uint256 public externalRewardClaimed;

  uint256 public lastExternalUpdateTime;
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
  }

  function approveLp() public {
    IERC20(uni_lp).safeApprove(externalIncentivizer, uint256(-1));
  }

  function externalRewardToken() public view returns (address) {
    return address(StakingPool(externalIncentivizer).rewardToken());
  }

  modifier updateExternalReward(address _account) {
    externalRewardStored = externalReward();
    externalRewardPerTokenStored = externalRewardPerToken();
    lastExternalUpdateTime = block.timestamp;
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
      rewardPerTokenStored.add(
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
    console.log("u r in the exit");
    withdraw(balanceOf(msg.sender));
    console.log("finish withdrew");
    getReward();
    console.log("finish got rewards");
  }

  function getReward() public override updateExternalReward(msg.sender) {
    super.getReward();
    console.log("finish to get reward from parent");

    uint256 _externalReward = externalRewards[msg.sender];
    console.log("_externalReward", _externalReward);
    if (_externalReward > 0) {
      externalRewards[msg.sender] = 0;

      // Claim external reward if the remaining balance is insufficient
      IERC20 _externalRewardToken = IERC20(externalRewardToken());
      uint256 balanceBefore = _externalRewardToken.balanceOf(address(this));
      console.log("balanceBefore", balanceBefore);
      if (balanceBefore < _externalReward) {
        StakingPool(externalIncentivizer).getReward();

        uint256 balanceAfter = _externalRewardToken.balanceOf(address(this));
        externalRewardClaimed = externalRewardClaimed.add(
          balanceAfter.sub(balanceBefore)
        );
      }

      _externalRewardToken.safeTransfer(msg.sender, _externalReward);

      emit ExternalRewardPaid(msg.sender, _externalReward);
    }
  }
}
