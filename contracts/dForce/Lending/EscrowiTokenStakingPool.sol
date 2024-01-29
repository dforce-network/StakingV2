//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./EscrowLendingStakingPool.sol";

/**
 * @title EscrowiTokenStakingPool Contract
 * @author dForce
 * @notice This contract is used for staking iTokens in an escrow lending staking pool.
 * @dev Inherits from EscrowLendingStakingPool to leverage the lending and staking mechanisms.
 */
contract EscrowiTokenStakingPool is EscrowLendingStakingPool {
  /**
   * @dev Constructor for EscrowiTokenStakingPool contract.
   * @param _lp Address of the liquidity pool token (iToken).
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
  )
    public
    EscrowLendingStakingPool(
      _lp,
      _rewardToken,
      _startTime,
      _freezingTime,
      _escrowAccount
    )
  {
    IERC20(IiToken(_lp).underlying()).safeApprove(_lp, uint256(-1));
  }

  /**
   * @dev Transfers all underlying assets to the escrow account after the freezing time has passed.
   * Can only be called by the owner of the contract.
   */
  function escrowUnderlyingTransfer() external onlyOwner {
    require(FREEZING_TIME < block.timestamp, "Freezing time has not expired");
    IiToken(address(uni_lp)).redeem(
      address(this),
      uni_lp.balanceOf(address(this))
    );
    UNDERLYING.safeTransfer(
      ESCROW_ACCOUNT,
      UNDERLYING.balanceOf(address(this))
    );
  }

  /**
   * @dev Allows users to mint new iTokens by sending underlying tokens and then stake them in the pool.
   * The function is only callable when the pool is not frozen and updates the reward for the sender.
   * @param _underlyingAmount The amount of underlying tokens to mint iTokens.
   */
  function mintAndStake(uint256 _underlyingAmount)
    external
    nonReentrant
    freeze
    updateReward(msg.sender)
  {
    address _sender = msg.sender;
    UNDERLYING.safeTransferFrom(_sender, address(this), _underlyingAmount);

    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiToken(address(uni_lp)).mint(address(this), _underlyingAmount);

    uint256 _amount = (uni_lp.balanceOf(address(this))).sub(_iTokenBalance);
    _totalSupply = _totalSupply.add(_amount);
    _balances[_sender] = _balances[_sender].add(_amount);

    emit Staked(_sender, _amount);
  }

  /**
   * @dev Allows users to redeem their underlying tokens and withdraw them from the pool.
   * The function is only callable when the pool is not frozen and updates the reward for the sender.
   * @param _underlyingAmount The amount of underlying tokens to redeem and withdraw.
   */
  function redeemUnderlyingAndWithdraw(uint256 _underlyingAmount)
    external
    nonReentrant
    freeze
    updateReward(msg.sender)
  {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiToken(address(uni_lp)).redeemUnderlying(address(this), _underlyingAmount);

    address _sender = msg.sender;
    uint256 _amount = (_iTokenBalance).sub(uni_lp.balanceOf(address(this)));
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    UNDERLYING.safeTransfer(_sender, _underlyingAmount);

    emit Withdrawn(_sender, _amount);
  }

  /**
   * @dev Allows users to redeem iTokens and withdraw the underlying tokens from the pool.
   * The function is only callable when the pool is not frozen and updates the reward for the sender.
   * @param _amount The amount of iTokens to redeem and withdraw the underlying tokens for.
   */
  function redeemAndWithdraw(uint256 _amount)
    public
    nonReentrant
    freeze
    updateReward(msg.sender)
  {
    uint256 _underlyingBalance = UNDERLYING.balanceOf(address(this));

    address _sender = msg.sender;
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    IiToken(address(uni_lp)).redeem(address(this), _amount);

    UNDERLYING.safeTransfer(
      _sender,
      (UNDERLYING.balanceOf(address(this))).sub(_underlyingBalance)
    );

    emit Withdrawn(_sender, _amount);
  }

  /**
   * @dev Allows users to exit the pool by redeeming all their staked iTokens and claiming their rewards.
   * This function combines redeeming and withdrawing in one call for convenience.
   */
  function exitUnderlying() external {
    redeemAndWithdraw(_balances[msg.sender]);
    getReward();
  }
}
