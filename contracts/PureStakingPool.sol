//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./Ownable.sol";
import "./LPTokenWrapper.sol";

contract PureStakingPool is Ownable, LPTokenWrapper {
  using SafeERC20 for IERC20;

  event Staked(address indexed user, uint256 amount, uint256 balance);
  event Withdrawn(address indexed user, uint256 amount, uint256 balance);

  constructor(address _lp) public {
    __Ownable_init();
    uni_lp = IERC20(_lp);
  }

  // stake visibility is public as overriding LPTokenWrapper's stake() function
  function stake(uint256 _amount) public override {
    require(_amount > 0, "Cannot stake 0");
    super.stake(_amount);
    address _sender = msg.sender;
    emit Staked(_sender, _amount, balanceOf(_sender));
  }

  function withdraw(uint256 _amount) public override {
    require(_amount > 0, "Cannot withdraw 0");
    super.withdraw(_amount);
    address _sender = msg.sender;
    emit Withdrawn(_sender, _amount, balanceOf(_sender));
  }

  // This function allows governance to take unsupported tokens out of the
  // contract, since this one exists longer than the other pools.
  // This is in an effort to make someone whole, should they seriously
  // mess up. There is no guarantee governance will vote to return these.
  // It also allows for removal of airdropped tokens.
  function rescueTokens(IERC20 _token, uint256 _amount, address _to) external onlyOwner {
    // cant take staked asset
    require(_token != uni_lp, "uni_lp");

    // transfer _to
    _token.safeTransfer(_to, _amount);
  }
}
