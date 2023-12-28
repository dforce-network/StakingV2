//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../EscrowStakingPool.sol";
import "./IDForceLending.sol";

abstract contract EscrowDForceLending is EscrowStakingPool {
  IERC20 internal immutable UNDERLYING;
  uint256 internal immutable FREEZE_DISTRIBUTION_END_TIME;

  uint256 internal freezeRewardRate_;

  event FreezeRewardRateUpdated(
    uint256 oldFreezeRewardRate,
    uint256 newFreezeRewardRate
  );

  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime,
    uint256 _freezingTime,
    uint256 _freezeDistributionDuration,
    address payable _escrowAccount
  )
    public
    EscrowStakingPool(
      _lp,
      _rewardToken,
      _startTime,
      _freezingTime,
      _escrowAccount
    )
  {
    UNDERLYING = IERC20(IiToken(_lp).underlying());
    FREEZE_DISTRIBUTION_END_TIME = _freezingTime.add(
      _freezeDistributionDuration
    );
  }

  function setFreezeRewardRate(uint256 _freezeRewardRate)
    external
    onlyOwner
    updateRewardDistributed
    updateReward(address(0))
  {
    uint256 _oldFreezeRewardRate = freezeRewardRate_;
    freezeRewardRate_ = _freezeRewardRate;

    emit FreezeRewardRateUpdated(_oldFreezeRewardRate, _freezeRewardRate);
  }

  function stake(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  function withdraw(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  function _freezeDistributionTime() internal view returns (uint256) {
    return Math.min(block.timestamp, FREEZE_DISTRIBUTION_END_TIME);
  }

  function rewardPerToken()
    public
    view
    override
    returns (uint256 _rewardPerTokenStored)
  {
    _rewardPerTokenStored = EscrowStakingPool.rewardPerToken();

    if (block.timestamp > FREEZING_TIME) {
      uint256 _lastTimeApplicable = Math.max(startTime, lastUpdateTime);
      uint256 _freezeDistributionTimestamp = _freezeDistributionTime();

      if (
        totalSupply() > 0 && _freezeDistributionTimestamp > _lastTimeApplicable
      ) {
        _rewardPerTokenStored = _rewardPerTokenStored.add(
          _freezeDistributionTimestamp
            .sub(_lastTimeApplicable)
            .mul(freezeRewardRate_)
            .mul(1e18)
            .div(totalSupply())
        );
      }
    }
  }

  function rewardDistributed()
    public
    view
    override
    returns (uint256 _rewardDistributedStored)
  {
    _rewardDistributedStored = EscrowStakingPool.rewardDistributed();
    if (block.timestamp > FREEZING_TIME)
      _rewardDistributedStored = _rewardDistributedStored
        .add(
        _freezeDistributionTime().sub(
          Math.min(FREEZE_DISTRIBUTION_END_TIME, lastRateUpdateTime)
        )
      )
        .mul(freezeRewardRate_);
  }

  function balanceOfUnderlying(address _account) external returns (uint256) {
    _balances[_account].mul(IiToken(address(uni_lp)).exchangeRateCurrent()).div(
      1e18
    );
  }

  function totalUnderlying() external returns (uint256) {
    return IiToken(address(uni_lp)).balanceOfUnderlying(address(this));
  }

  function lendingCash() external view returns (uint256) {
    return IiToken(address(uni_lp)).getCash();
  }

  /**
   * @dev dForce lending limit of deposit.
   */
  function limitOfDeposit() external returns (uint256 _depositLimit) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , uint256 _supplyCapacity, , , ) =
      IController(_iToken.controller()).markets(address(_iToken));

    uint256 _totalUnderlying =
      _iToken.totalSupply().mul(_iToken.exchangeRateCurrent()).div(1e18);

    if (_supplyCapacity > _totalUnderlying)
      _depositLimit = _supplyCapacity - _totalUnderlying;
  }

  /**
   * @dev The deposit status of the strategy.
   */
  function depositStatus() external view returns (bool _mintPaused) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , , _mintPaused, , ) = IController(_iToken.controller()).markets(
      address(_iToken)
    );
  }

  /**
   * @dev The withdraw status of the strategy.
   */
  function withdrawStatus() external view returns (bool _redeemPaused) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , , , _redeemPaused, ) = IController(_iToken.controller()).markets(
      address(_iToken)
    );
  }

  function underlying() external view returns (IERC20) {
    return UNDERLYING;
  }
}
