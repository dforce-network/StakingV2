// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IExternalIncentivizer {
  function rewardToken() external view returns (IERC20);

  function earned(address _account) external view returns (uint256);

  function stake(uint256 _amount) external;

  function withdraw(uint256 _amount) external;

  function getReward() external;
}
