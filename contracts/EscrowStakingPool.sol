//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StakingPool.sol";

contract EscrowStakingPool is StakingPool {
  uint256 internal periodFinish_;

  event SetPeriodFinish(uint256 periodFinish);

  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime
  ) public StakingPool(_lp, _rewardToken, _startTime) {}

  modifier expired() {
    uint256 _periodFinish = periodFinish_;
    if (_periodFinish > 0) {
      require(_periodFinish >= block.timestamp, "uni_lp");
    }
    _;
  }

  function setPeriodFinish(uint256 _periodFinish)
    external
    onlyOwner
    updateReward(address(0))
  {
    require(rewardRate == 0, "uni_lp");
    require(_periodFinish > block.timestamp, "uni_lp");
    periodFinish_ = _periodFinish;

    emit SetPeriodFinish(_periodFinish);
  }

  function setRewardRate(uint256 _rewardRate) public override expired {
    StakingPool.setRewardRate(_rewardRate);
  }

  function escrowTransfer(address _receiver) external onlyOwner {
    require(periodFinish_ < block.timestamp, "uni_lp");
    uni_lp.safeTransfer(_receiver, uni_lp.balanceOf(address(this)));
  }

  function stake(uint256 _amount) public override expired {
    StakingPool.stake(_amount);
  }

  function withdraw(uint256 _amount) public override expired {
    StakingPool.withdraw(_amount);
  }

  function periodFinish() external view returns (uint256) {
    return periodFinish_;
  }
}
