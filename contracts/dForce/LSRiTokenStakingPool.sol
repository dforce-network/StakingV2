//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../StakingPool.sol";

import "../interface/IERC20Pro.sol";
import "./Lending/IDForceLending.sol";
import "./LSR/ILSR.sol";

/**
 * @title LSRiTokenStakingPool Contract
 * @author dForce
 * @notice This contract is used for staking iTokens in an LSR staking pool.
 * @dev Inherits from StakingPool to leverage the staking mechanisms.
 */
contract LSRiTokenStakingPool is StakingPool {
  ILSR internal immutable LSR; // LSR contract instance
  IERC20 internal immutable MSD; // MSD token instance
  IERC20 internal immutable MPR; // MPR token instance

  uint256 internal immutable msdDecimalScaler_; // Decimal scaler for MSD token
  uint256 internal immutable mprDecimalScaler_; // Decimal scaler for MPR token

  /**
   * @dev Constructor to initialize the LSRiTokenStakingPool
   * @param _lp The address of the LP
   * @param _lsr The address of the LSR
   * @param _rewardToken The address of the reward token
   * @param _startTime The start time for staking
   */
  constructor(
    address _lp,
    address _lsr,
    address _rewardToken,
    uint256 _startTime
  ) public StakingPool(_lp, _rewardToken, _startTime) {
    LSR = ILSR(_lsr);

    IERC20 _msd = IERC20(ILSR(_lsr).msd());
    require(_msd == IERC20(IiToken(_lp).underlying()), "MSD address mismatch");
    MSD = _msd;
    _msd.safeApprove(_lp, uint256(-1));

    IERC20 _mpr = IERC20(ILSR(_lsr).mpr());
    MPR = _mpr;
    _mpr.safeApprove(_lsr, uint256(-1));

    msdDecimalScaler_ = 10**uint256(IERC20Pro(address(_msd)).decimals());
    mprDecimalScaler_ = 10**uint256(IERC20Pro(address(_mpr)).decimals());
  }

  /**
   * @dev Function to stake the specified amount
   * @param _amount The amount to stake
   */
  function stake(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  /**
   * @dev Function to withdraw the specified amount
   * @param _amount The amount to withdraw
   */
  function withdraw(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  function buyMsdAndStake(uint256 _mprAmount)
    external
    updateReward(msg.sender)
  {
    address _sender = msg.sender;
    MPR.safeTransferFrom(_sender, address(this), _mprAmount);

    LSR.buyMsd(_mprAmount);
    uint256 _msdAmount = LSR.getAmountToBuy(_mprAmount);

    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiToken(address(uni_lp)).mint(address(this), _msdAmount);

    uint256 _amount = (uni_lp.balanceOf(address(this))).sub(_iTokenBalance);
    _totalSupply = _totalSupply.add(_amount);
    _balances[_sender] = _balances[_sender].add(_amount);

    emit Staked(_sender, _amount);
  }

  function redeemUnderlyingAndWithdraw(uint256 _msdAmount)
    external
    updateReward(msg.sender)
  {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiToken(address(uni_lp)).redeemUnderlying(address(this), _msdAmount);

    address _sender = msg.sender;
    uint256 _amount = _iTokenBalance.sub(uni_lp.balanceOf(address(this)));
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    MSD.safeTransfer(_sender, _msdAmount);

    emit Withdrawn(_sender, _amount);
  }

  function redeemAndWithdraw(uint256 _amount) public updateReward(msg.sender) {
    uint256 _msdBalance = MSD.balanceOf(address(this));

    address _sender = msg.sender;
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    IiToken(address(uni_lp)).redeem(address(this), _amount);

    MSD.safeTransfer(_sender, (MSD.balanceOf(address(this))).sub(_msdBalance));

    emit Withdrawn(_sender, _amount);
  }

  function exitUnderlying() external {
    redeemAndWithdraw(_balances[msg.sender]);
    getReward();
  }

  function currentRewardRate()
    external
    view
    returns (uint256 _distributionRewardRate)
  {
    if (block.timestamp >= startTime) _distributionRewardRate = rewardRate;
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

  function lendingLimitOfDeposit()
    public
    returns (uint256 _lendingLimitOfDeposit)
  {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , uint256 _supplyCapacity, , , ) =
      IController(_iToken.controller()).markets(address(_iToken));

    uint256 _totalUnderlying =
      _iToken.totalSupply().mul(_iToken.exchangeRateCurrent()).div(1e18);

    if (_supplyCapacity > _totalUnderlying)
      _lendingLimitOfDeposit = _supplyCapacity - _totalUnderlying;
  }

  function _calculator(
    uint256 _amount,
    uint256 _decimalScalerIn,
    uint256 _decimalScalerOut
  ) internal pure returns (uint256) {
    return _amount.mul(_decimalScalerOut).div(_decimalScalerIn);
  }

  function LSRLimitOfDeposit() public returns (uint256 _LSRLimitOfDeposit) {
    _LSRLimitOfDeposit = IStrategy(LSR.strategy()).limitOfDeposit();

    uint256 _mprQuota =
      _calculator(LSR.msdQuota(), msdDecimalScaler_, mprDecimalScaler_);

    if (_LSRLimitOfDeposit > _mprQuota) _LSRLimitOfDeposit = _mprQuota;
  }

  function limitOfDeposit() external returns (uint256 _limitOfDeposit) {
    _limitOfDeposit = LSRLimitOfDeposit();

    uint256 _lendingLimitOfDeposit =
      _calculator(
        lendingLimitOfDeposit(),
        msdDecimalScaler_,
        mprDecimalScaler_
      );

    if (_limitOfDeposit > _lendingLimitOfDeposit)
      _limitOfDeposit = _lendingLimitOfDeposit;
  }

  function lendingDepositStatus() public view returns (bool _mintPaused) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , , _mintPaused, , ) = IController(_iToken.controller()).markets(
      address(_iToken)
    );
  }

  function lendingWithdrawStatus() public view returns (bool _redeemPaused) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , , , _redeemPaused, ) = IController(_iToken.controller()).markets(
      address(_iToken)
    );
  }

  function LSRDepositStatus() public returns (bool) {
    return IStrategy(LSR.strategy()).depositStatus();
  }

  function depositStatus() external returns (bool) {
    return LSRDepositStatus() || lendingDepositStatus();
  }

  function withdrawStatus() external view returns (bool) {
    return lendingWithdrawStatus();
  }

  function lsr() external view returns (ILSR) {
    return LSR;
  }

  function msd() external view returns (IERC20) {
    return MSD;
  }

  function mpr() external view returns (IERC20) {
    return MPR;
  }

  function msdDecimalScaler() external view returns (uint256) {
    return msdDecimalScaler_;
  }

  function mprDecimalScaler() external view returns (uint256) {
    return mprDecimalScaler_;
  }
}
