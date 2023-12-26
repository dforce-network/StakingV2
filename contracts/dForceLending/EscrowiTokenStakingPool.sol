//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./EscrowDForceLending.sol";

contract EscrowiTokenStakingPool is EscrowDForceLending {
  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime,
    uint256 _freezingTime,
    address payable _escrowAccount
  )
    public
    EscrowDForceLending(
      _lp,
      _rewardToken,
      _startTime,
      _freezingTime,
      _escrowAccount
    )
  {
    IERC20(IiToken(_lp).underlying()).safeApprove(_lp, uint256(-1));
  }

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

  function mintAndStake(uint256 _underlyingAmount)
    external
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

    emit Withdrawn(_sender, _amount);
  }

  function redeemAndWithdraw(uint256 _amount)
    external
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

  function redeemUnderlyingAndWithdraw(uint256 _underlyingAmount)
    external
    freeze
    updateReward(msg.sender)
  {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    IiToken(address(uni_lp)).redeemUnderlying(address(this), _underlyingAmount);

    address _sender = msg.sender;
    uint256 _amount = (uni_lp.balanceOf(address(this))).sub(_iTokenBalance);
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    UNDERLYING.safeTransfer(_sender, _underlyingAmount);

    emit Withdrawn(_sender, _amount);
  }
}
