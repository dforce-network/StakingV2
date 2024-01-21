//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./StakingPool.sol";

/**
 * @title Escrow Staking Pool Contract
 * @author dForce
 * @notice This contract is used to create an escrow staking pool for dForce's lending model.
 * @dev This contract extends StakingPool and includes additional state variables and constructor logic specific to the escrow mechanism.
 */
contract EscrowStakingPool is StakingPool {
  // The timestamp after which no more staking or other actions are possible.
  uint256 internal immutable FREEZING_TIME;
  // The account to which the funds will be transferred after the freezing time.
  address payable internal immutable ESCROW_ACCOUNT;

  // Event emitted when the freezing time is set.
  event SetFreezingTime(uint256 freezingTime);
  // Event emitted when the escrow account is set.
  event SetEscrowAccount(address escrowAccount);

  /**
   * @dev Constructor for EscrowStakingPool contract.
   * @dev The constructor sets the initial state of the contract including the liquidity pool token, reward token, start time, freezing time, and escrow account.
   * @dev It also validates the inputs, ensuring that the freezing time is in the future and the escrow account is not the zero address.
   * @param _lp Address of the liquidity pool token.
   * @param _rewardToken Address of the reward token.
   * @param _startTime Start time of the staking pool.
   * @param _freezingTime Time after which no more staking or other actions are possible.
   * @param _escrowAccount Address to which the funds will be transferred after freezing time.
   */
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

  /**
   * @dev Sets the reward rate for the staking pool. Can only be called when the contract is frozen.
   * @param _rewardRate The new reward rate to be set for the staking pool.
   */
  function setRewardRate(uint256 _rewardRate) public override freeze {
    StakingPool.setRewardRate(_rewardRate);
  }

  /**
   * @dev Transfers the entire balance of the liquidity pool tokens to the escrow account.
   * Can only be called by the owner after the freezing time has expired.
   */
  function escrowTransfer() external onlyOwner {
    require(FREEZING_TIME < block.timestamp, "Freezing time has not expired");
    uni_lp.safeTransfer(ESCROW_ACCOUNT, uni_lp.balanceOf(address(this)));
  }

  /**
   * @dev Allows a user to stake a specified amount of tokens.
   * Staking is only possible if the freezing time has not been reached.
   * @param _amount The amount of tokens to stake.
   */
  function stake(uint256 _amount) public virtual override freeze {
    StakingPool.stake(_amount);
  }

  /**
   * @dev Allows a user to withdraw a specified amount of their staked tokens.
   * Withdrawal is only possible if the freezing time has not been reached.
   * @param _amount The amount of tokens to withdraw.
   */
  function withdraw(uint256 _amount) public virtual override freeze {
    StakingPool.withdraw(_amount);
  }

  /**
   * @dev Internal function to determine the time of reward distribution.
   * It returns the minimum between the current time and the freezing time.
   * @return The timestamp used for calculating reward distribution.
   */
  function _distributionTime() internal view returns (uint256) {
    return Math.min(block.timestamp, FREEZING_TIME);
  }

  /**
   * @dev Calculates the reward per token by considering the time elapsed since the last update.
   * It takes into account the freezing time for the calculation.
   * @return The calculated reward per token.
   */
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

  /**
   * @dev Calculates the total reward distributed by considering the time elapsed.
   * It takes into account the freezing time for the calculation.
   * @return The total reward distributed.
   */
  function rewardDistributed() public view virtual override returns (uint256) {
    uint256 _distributionTimestamp = _distributionTime();
    if (_distributionTimestamp < startTime) {
      return rewardDistributedStored;
    }

    return
      rewardDistributedStored.add(
        _distributionTimestamp
          .sub(Math.max(startTime, Math.min(lastRateUpdateTime, FREEZING_TIME)))
          .mul(rewardRate)
      );
  }

  /**
   * @dev Returns the current reward rate, considering the freezing time.
   * @return _distributionRewardRate The current distribution reward rate.
   */
  function currentRewardRate()
    external
    view
    virtual
    returns (uint256 _distributionRewardRate)
  {
    // Determine the current reward rate based on the freezing time
    if (block.timestamp >= startTime && block.timestamp <= FREEZING_TIME)
      _distributionRewardRate = rewardRate;
  }

  /**
   * @dev Returns the freezing time of the contract.
   * @return The freezing time.
   */
  function freezingTime() external view returns (uint256) {
    return FREEZING_TIME;
  }

  /**
   * @dev Returns the escrow account address.
   * @return The escrow account address.
   */
  function escrowAccount() external view returns (address) {
    return ESCROW_ACCOUNT;
  }
}
