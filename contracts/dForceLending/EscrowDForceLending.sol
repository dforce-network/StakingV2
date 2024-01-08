//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../EscrowStakingPool.sol";
import "./IDForceLending.sol";

abstract contract EscrowDForceLending is EscrowStakingPool {
  IERC20 internal immutable UNDERLYING;

  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime,
    uint256 _freezingTime,
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
  }

  function stake(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  function withdraw(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  function balanceOfUnderlying(address _account) external returns (uint256) {
    return
      _balances[_account]
        .mul(IiToken(address(uni_lp)).exchangeRateCurrent())
        .div(1e18);
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
