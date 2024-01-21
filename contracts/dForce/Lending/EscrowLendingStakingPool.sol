//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../../EscrowStakingPool.sol";
import "./IDForceLending.sol";

/**
 * @title Escrow Lending Staking Pool Contract
 * @author dForce
 * @notice This contract is used to create an escrow staking pool for dForce's lending model.
 * @dev This abstract contract extends the EscrowStakingPool with lending-specific functionality.
 * It inherits from EscrowStakingPool and includes additional methods for lending operations.
 */
abstract contract EscrowLendingStakingPool is EscrowStakingPool {
  IERC20 internal immutable UNDERLYING;

  /**
   * @dev Constructor for EscrowLendingStakingPool contract.
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

  /**
   * @dev Stakes a certain amount of tokens into the pool.
   * Currently, this function reverts as it's not implemented.
   * @param _amount The amount of tokens to stake.
   */
  function stake(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  /**
   * @dev Withdraws a certain amount of tokens from the pool.
   * Currently, this function reverts as it's not implemented.
   * @param _amount The amount of tokens to withdraw.
   */
  function withdraw(uint256 _amount) public virtual override {
    _amount;
    revert();
  }

  /**
   * @dev Returns the balance of the underlying asset for a given account.
   * @param _account The address of the account to check.
   * @return The amount of underlying tokens the account has in the pool.
   */
  function balanceOfUnderlying(address _account) external returns (uint256) {
    return
      _balances[_account]
        .mul(IiToken(address(uni_lp)).exchangeRateCurrent())
        .div(1e18);
  }

  /**
   * @dev Returns the total balance of the underlying asset held by the pool.
   * @return The total amount of underlying tokens the pool has.
   */
  function totalUnderlying() external returns (uint256) {
    return IiToken(address(uni_lp)).balanceOfUnderlying(address(this));
  }

  /**
   * @dev Returns the available cash (liquidity) in the pool.
   * @return The amount of available cash in the pool.
   */
  function lendingCash() external view returns (uint256) {
    return IiToken(address(uni_lp)).getCash();
  }

  /**
   * @dev Returns the remaining deposit limit of the pool.
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
   * @dev Returns the deposit status of the pool.
   */
  function depositStatus() external view returns (bool _mintPaused) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , , _mintPaused, , ) = IController(_iToken.controller()).markets(
      address(_iToken)
    );
  }

  /**
   * @dev Returns the withdraw status of the pool.
   */
  function withdrawStatus() external view returns (bool _redeemPaused) {
    IiToken _iToken = IiToken(address(uni_lp));
    (, , , , , _redeemPaused, ) = IController(_iToken.controller()).markets(
      address(_iToken)
    );
  }

  /**
   * @dev Returns the underlying asset of the pool.
   */
  function underlying() external view returns (IERC20) {
    return UNDERLYING;
  }
}
