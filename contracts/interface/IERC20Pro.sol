// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Pro is IERC20 {
  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);
}
