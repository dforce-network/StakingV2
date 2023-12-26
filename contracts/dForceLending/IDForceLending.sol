//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IController {
  function rewardDistributor() external view returns (address);

  function markets(address _iToken)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256,
      bool,
      bool,
      bool
    );

  function _setSupplyCapacity(address _iToken, uint256 _newSupplyCapacity)
    external;
}

interface IRewardDistributor {
  function reward(address _account) external view returns (uint256);

  function rewardToken() external view returns (address);

  function updateRewardBatch(
    address[] memory _holders,
    address[] memory _iTokens
  ) external;

  function claimRewards(
    address[] memory _holders,
    address[] memory _suppliediTokens,
    address[] memory _borrowediTokens
  ) external;

  function claimAllReward(address[] memory _holders) external;
}

interface IiToken {
  function symbol() external view returns (string memory);

  function isSupported() external view returns (bool);

  function isiToken() external view returns (bool);

  function underlying() external view returns (address);

  function controller() external view returns (address);

  function exchangeRateCurrent() external returns (uint256);

  function totalSupply() external view returns (uint256);

  function balanceOf(address _account) external view returns (uint256);

  function getCash() external view returns (uint256);

  function balanceOfUnderlying(address _account) external returns (uint256);

  function mint(address _recipient, uint256 _mintAmount) external;

  function redeem(address _from, uint256 _redeemTokens) external;

  function redeemUnderlying(address _from, uint256 _redeemAmount) external;
}

interface iETH {
  function symbol() external view returns (string memory);

  function isSupported() external view returns (bool);

  function isiToken() external view returns (bool);

  function underlying() external view returns (address);

  function controller() external view returns (address);

  function exchangeRateCurrent() external returns (uint256);

  function totalSupply() external view returns (uint256);

  function balanceOf(address _account) external view returns (uint256);

  function getCash() external view returns (uint256);

  function balanceOfUnderlying(address _account) external returns (uint256);

  function mint(address _recipient) external payable;

  function redeem(address _from, uint256 _redeemTokens) external;

  function redeemUnderlying(address _from, uint256 _redeemAmount) external;
}
