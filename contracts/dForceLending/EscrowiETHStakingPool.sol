//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./EscrowDForceLending.sol";

contract EscrowiETHStakingPool is EscrowDForceLending {
  constructor(
    address _lp,
    address _rewardToken,
    uint256 _startTime,
    uint256 _freezingTime,
    uint256 _freezeDistributionDuration,
    address payable _escrowAccount
  )
    public
    EscrowDForceLending(
      _lp,
      _rewardToken,
      _startTime,
      _freezingTime,
      _freezeDistributionDuration,
      _escrowAccount
    )
  {}

  receive() external payable {}

  function escrowUnderlyingTransfer() external onlyOwner {
    require(FREEZING_TIME < block.timestamp, "Freezing time has not expired");
    iETH(address(uni_lp)).redeem(
      address(this),
      uni_lp.balanceOf(address(this))
    );
    ESCROW_ACCOUNT.transfer(address(this).balance);
  }

  function mintAndStake() external payable freeze updateReward(msg.sender) {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    iETH(address(uni_lp)).mint{ value: msg.value }(address(this));

    address payable _sender = msg.sender;
    uint256 _amount = (uni_lp.balanceOf(address(this))).sub(_iTokenBalance);
    _totalSupply = _totalSupply.add(_amount);
    _balances[_sender] = _balances[_sender].add(_amount);

    emit Staked(_sender, _amount);
  }

  function redeemUnderlyingAndWithdraw(uint256 _underlyingAmount)
    external
    freeze
    updateReward(msg.sender)
  {
    uint256 _iTokenBalance = uni_lp.balanceOf(address(this));

    iETH(address(uni_lp)).redeemUnderlying(address(this), _underlyingAmount);

    address payable _sender = msg.sender;
    uint256 _amount = (uni_lp.balanceOf(address(this))).sub(_iTokenBalance);
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    _sender.transfer(_underlyingAmount);

    emit Withdrawn(_sender, _amount);
  }

  function redeemAndWithdraw(uint256 _amount)
    public
    freeze
    updateReward(msg.sender)
  {
    uint256 _underlyingBalance = address(this).balance;

    address payable _sender = msg.sender;
    _totalSupply = _totalSupply.sub(_amount);
    _balances[_sender] = _balances[_sender].sub(_amount);

    iETH(address(uni_lp)).redeem(address(this), _amount);

    _sender.transfer(address(this).balance.sub(_underlyingBalance));

    emit Withdrawn(_sender, _amount);
  }

  function exitUnderlying() external {
    redeemAndWithdraw(_balances[msg.sender]);
    getReward();
  }
}
