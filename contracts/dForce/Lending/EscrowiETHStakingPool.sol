//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./EscrowLendingStakingPool.sol";

/**
 * @title EscrowiETHStakingPool Contract
 * @author dForce
 * @notice This contract is used for staking iETH in an escrow lending staking pool.
 * @dev Inherits from EscrowLendingStakingPool to leverage the lending and staking mechanisms.
 */
contract EscrowiETHStakingPool is EscrowLendingStakingPool {
  /**
   * @dev Constructor for EscrowiETHStakingPool contract.
   * @param _lp Address of the liquidity pool token (iETH).
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
  {}

  /**
   * @dev Fallback function to accept ETH when sent directly to the contract.
   */
  receive() external payable {}

  /**
   * @dev Transfers all underlying assets to the escrow account after the freezing time has passed.
   * Can only be called by the owner of the contract.
   */
  function escrowUnderlyingTransfer() external onlyOwner {
    require(FREEZING_TIME < block.timestamp, "Freezing time has not expired");
    IiETH(address(uni_lp)).redeem(
      address(this),
      uni_lp.balanceOf(address(this))
    );
    ESCROW_ACCOUNT.transfer(address(this).balance);
  }

  /**
   * @dev Allows users to mint new iETH tokens by sending ETH and then stake them in the pool.
   * The function is only callable when the pool is not frozen and updates the reward for the sender.
   */
  function mintAndStake()
    external
    payable
    nonReentrant
    freeze
    updateReward(msg.sender)
  {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiETH(address(uni_lp)).mint{ value: msg.value }(address(this));

    address payable _sender = msg.sender;
    uint256 _amount = (uni_lp.balanceOf(address(this))).sub(_iTokenBalance);
    _totalSupply = _totalSupply.add(_amount);
    _balances[_sender] = _balances[_sender].add(_amount);

    emit Staked(_sender, _amount);
  }

  /**
   * @dev Allows users to redeem their underlying ETH and withdraw it from the pool.
   * The function is only callable when the pool is not frozen and updates the reward for the sender.
   * @param _underlyingAmount The amount of underlying ETH to redeem and withdraw.
   */
  function redeemUnderlyingAndWithdraw(uint256 _underlyingAmount)
    external
    nonReentrant
    freeze
    updateReward(msg.sender)
  {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiETH(address(uni_lp)).redeemUnderlying(address(this), _underlyingAmount);

    address payable _sender = msg.sender;
    uint256 _amount = (_iTokenBalance).sub(uni_lp.balanceOf(address(this)));
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    _sender.transfer(_underlyingAmount);

    emit Withdrawn(_sender, _amount);
  }

  /**
   * @dev Allows users to redeem iETH tokens and withdraw the underlying ETH from the pool.
   * The function is only callable when the pool is not frozen and updates the reward for the sender.
   * @param _amount The amount of iETH tokens to redeem and withdraw the underlying ETH for.
   */
  function redeemAndWithdraw(uint256 _amount)
    public
    nonReentrant
    freeze
    updateReward(msg.sender)
  {
    uint256 _underlyingBalance = address(this).balance;

    address payable _sender = msg.sender;
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    IiETH(address(uni_lp)).redeem(address(this), _amount);

    _sender.transfer(address(this).balance.sub(_underlyingBalance));

    emit Withdrawn(_sender, _amount);
  }

  /**
   * @dev Allows users to exit the pool by redeeming all their staked iETH tokens and claiming their rewards.
   * This function combines redeeming and withdrawing in one call for convenience.
   */
  function exitUnderlying() external {
    redeemAndWithdraw(_balances[msg.sender]);
    getReward();
  }
}
