//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../dForceLending/IDForceLending.sol";

contract Controller is IController {
  function rewardDistributor() external view override returns (address) {
    return address(0);
  }

  function markets(address _iToken)
    external
    view
    override
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      bool,
      bool,
      bool
    )
  {
    _iToken;
    return (0, 0, 0, type(uint256).max, false, false, false);
  }

  function _setSupplyCapacity(address _iToken, uint256 _newSupplyCapacity)
    external
    override
  {
    _iToken;
    _newSupplyCapacity;
  }
}

contract iToken is IiToken {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address internal immutable controller_;
  IERC20 internal immutable underlying_;

  uint256 public override totalSupply;
  mapping(address => uint256) public override balanceOf;

  event Transfer(address indexed from, address indexed to, uint256 value);

  constructor(address _controller, IERC20 _underlying) public {
    controller_ = _controller;
    underlying_ = _underlying;
  }

  function symbol() external view override returns (string memory) {
    return "iToken";
  }

  function isSupported() external view override returns (bool) {
    return true;
  }

  function isiToken() external view override returns (bool) {
    return true;
  }

  function controller() external view override returns (address) {
    return controller_;
  }

  function underlying() external view override returns (address) {
    return address(underlying_);
  }

  function _exchangeRate() internal view returns (uint256) {
    return
      totalSupply == 0
        ? 1e18
        : underlying_.balanceOf(address(this)).mul(1e18).div(totalSupply);
  }

  function exchangeRateCurrent() external override returns (uint256) {
    return _exchangeRate();
  }

  function getCash() external view override returns (uint256) {
    return underlying_.balanceOf(address(this));
  }

  function balanceOfUnderlying(address _account)
    external
    override
    returns (uint256)
  {
    balanceOf[_account].mul(_exchangeRate()).div(1e18);
  }

  function mint(address _recipient, uint256 _mintAmount) external override {
    uint256 _exchange = _exchangeRate();
    underlying_.safeTransferFrom(msg.sender, address(this), _mintAmount);
    uint256 _amount = _mintAmount.mul(1e18).div(_exchange);
    totalSupply = totalSupply.add(_amount);
    balanceOf[_recipient] = balanceOf[_recipient].add(_amount);
  }

  function redeem(address _from, uint256 _redeemTokens) external override {
    uint256 _exchange = _exchangeRate();
    totalSupply = totalSupply.sub(_redeemTokens);
    balanceOf[_from] = balanceOf[_from].sub(_redeemTokens);
    underlying_.safeTransfer(
      msg.sender,
      _redeemTokens.mul(_exchange).div(1e18)
    );
  }

  function redeemUnderlying(address _from, uint256 _redeemAmount)
    external
    override
  {
    uint256 _exchange = _exchangeRate();
    uint256 _redeemTokens =
      _redeemAmount.mul(1e18).add(_exchange.sub(1)).div(_exchange);
    totalSupply = totalSupply.sub(_redeemTokens);
    balanceOf[_from] = balanceOf[_from].sub(_redeemTokens);
    underlying_.safeTransfer(msg.sender, _redeemAmount);
  }

  function transfer(address _recipient, uint256 _amount)
    external
    returns (bool)
  {
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(
      _amount,
      "ERC20: transfer amount exceeds balance"
    );
    balanceOf[_recipient] = balanceOf[_recipient].add(_amount);
    emit Transfer(msg.sender, _recipient, _amount);
    return true;
  }
}

contract iETH is IiETH {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address internal immutable controller_;

  uint256 public openCash;

  uint256 public override totalSupply;
  mapping(address => uint256) public override balanceOf;

  event Transfer(address indexed from, address indexed to, uint256 value);

  constructor(address _controller) public {
    controller_ = _controller;
  }

  receive() external payable {}

  function symbol() external view override returns (string memory) {
    return "iETH";
  }

  function isSupported() external view override returns (bool) {
    return true;
  }

  function isiToken() external view override returns (bool) {
    return true;
  }

  function controller() external view override returns (address) {
    return controller_;
  }

  function underlying() external view override returns (address) {
    return address(0);
  }

  function _exchangeRate() internal view returns (uint256) {
    return
      totalSupply == 0
        ? 1e18
        : address(this).balance.sub(openCash).mul(1e18).div(totalSupply);
  }

  function exchangeRateCurrent() external override returns (uint256) {
    return _exchangeRate();
  }

  function getCash() external view override returns (uint256) {
    return address(this).balance.sub(openCash);
  }

  function balanceOfUnderlying(address _account)
    external
    override
    returns (uint256)
  {
    balanceOf[_account].mul(_exchangeRate()).div(1e18);
  }

  function mint(address _recipient) external payable override {
    openCash = msg.value;
    uint256 _amount = openCash.mul(1e18).div(_exchangeRate());
    totalSupply = totalSupply.add(_amount);
    balanceOf[_recipient] = balanceOf[_recipient].add(_amount);
    openCash = 0;
  }

  function redeem(address _from, uint256 _redeemTokens) external override {
    uint256 _exchange = _exchangeRate();
    totalSupply = totalSupply.sub(_redeemTokens);
    balanceOf[_from] = balanceOf[_from].sub(_redeemTokens);
    msg.sender.transfer(_redeemTokens.mul(_exchange).div(1e18));
  }

  function redeemUnderlying(address _from, uint256 _redeemAmount)
    external
    override
  {
    uint256 _exchange = _exchangeRate();
    uint256 _redeemTokens =
      _redeemAmount.mul(1e18).add(_exchange.sub(1)).div(_exchange);
    totalSupply = totalSupply.sub(_redeemTokens);
    balanceOf[_from] = balanceOf[_from].sub(_redeemTokens);
    msg.sender.transfer(_redeemAmount);
  }

  function transfer(address _recipient, uint256 _amount)
    external
    returns (bool)
  {
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(
      _amount,
      "ERC20: transfer amount exceeds balance"
    );
    balanceOf[_recipient] = balanceOf[_recipient].add(_amount);
    emit Transfer(msg.sender, _recipient, _amount);
    return true;
  }
}
