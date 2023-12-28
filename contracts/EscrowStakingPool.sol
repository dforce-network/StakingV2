//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StakingPool.sol";

contract EscrowStakingPool is StakingPool {
  uint256 internal immutable FREEZING_TIME;
  address payable internal immutable ESCROW_ACCOUNT;

  event SetFreezingTime(uint256 freezingTime);
  event SetEscrowAccount(address escrowAccount);

  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime,
    uint256 _freezingTime,
    address payable _escrowAccount
  ) public StakingPool(_lp, _rewardToken, _startTime) {
    require(_freezingTime > block.timestamp, "Freeze time is invalid");
    FREEZING_TIME = _freezingTime;
    emit SetFreezingTime(_freezingTime);

    require(_escrowAccount != address(0), "Escrow account is invalid");
    ESCROW_ACCOUNT = _escrowAccount;
    emit SetEscrowAccount(_escrowAccount);
  }

  modifier freeze() {
    require(FREEZING_TIME >= block.timestamp, "Freezing time has entered");
    _;
  }

  function setRewardRate(uint256 _rewardRate) public override freeze {
    StakingPool.setRewardRate(_rewardRate);
  }

  function escrowTransfer() external onlyOwner {
    require(FREEZING_TIME < block.timestamp, "Freezing time has not expired");
    uni_lp.safeTransfer(ESCROW_ACCOUNT, uni_lp.balanceOf(address(this)));
  }

  function stake(uint256 _amount) public virtual override freeze {
    StakingPool.stake(_amount);
  }

  function withdraw(uint256 _amount) public virtual override freeze {
    StakingPool.withdraw(_amount);
  }

  function _distributionTime() internal view returns (uint256) {
    return Math.min(block.timestamp, FREEZING_TIME);
  }

  function rewardPerToken() public view virtual override returns (uint256) {
    uint256 _lastTimeApplicable = Math.max(startTime, lastUpdateTime);
    uint256 _distributionTimestamp = _distributionTime();

    if (totalSupply() == 0 || _distributionTimestamp < _lastTimeApplicable) {
      return rewardPerTokenStored;
    }

    return
      rewardPerTokenStored.add(
        _distributionTimestamp
          .sub(_lastTimeApplicable)
          .mul(rewardRate)
          .mul(1e18)
          .div(totalSupply())
      );
  }

  function rewardDistributed() public view virtual override returns (uint256) {
    uint256 _distributionTimestamp = _distributionTime();
    // Have not started yet
    if (_distributionTimestamp < startTime) {
      return rewardDistributedStored;
    }

    return
      rewardDistributedStored.add(
        _distributionTimestamp.sub(Math.max(startTime, lastRateUpdateTime)).mul(
          rewardRate
        )
      );
  }

  function currentRewardRate()
    external
    view
    virtual
    returns (uint256 _distributionRewardRate)
  {
    if (FREEZING_TIME >= block.timestamp) _distributionRewardRate = rewardRate;
  }

  function freezingTime() external view returns (uint256) {
    return FREEZING_TIME;
  }

  function escrowAccount() external view returns (address) {
    return ESCROW_ACCOUNT;
  }
}
