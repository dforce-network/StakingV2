// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ILSRFactory {
  /// @dev Fetches all LSRs along with their associated MSDs and MPRs
  function getAllLSRs()
    external
    view
    returns (
      address[] memory _allLsrs,
      address[] memory _msds,
      address[] memory _mprs
    );
}

interface ILSR {
  /// @dev Returns the address of the Multi-currency Stable Debt Token (USX token)
  function msd() external view returns (address);

  /// @dev Returns the address of the MSD peg reserve (DAI/USDC/USDT)
  function mpr() external view returns (address);

  /// @dev Allows the purchase of MSD using MPR
  function buyMsd(uint256 _mprAmount) external;

  /// @dev Allows the sale of MSD in exchange for MPR
  function sellMsd(uint256 _msdAmount) external;

  /// @dev Calculates the amount of MSD that can be bought with a given amount of MPR
  function getAmountToBuy(uint256 _amountIn) external view returns (uint256);

  /// @dev Calculates the amount of MPR that can be received for a given amount of MSD
  function getAmountToSell(uint256 _amountIn) external view returns (uint256);

  /// @dev Returns the address of the strategy contract associated with this LSR
  function strategy() external view returns (address);

  /// @dev Returns the quota of MSD that can be issued by this LSR
  function msdQuota() external view returns (uint256);
}

interface IStrategy {
  // Returns the address of the liquidity model contract
  function liquidityModel() external view returns (address);

  // Returns the total amount of deposits in the strategy
  function totalDeposits() external returns (uint256);

  // Returns the current liquidity of the strategy
  function liquidity() external returns (uint256);

  // Returns the amount of rewards earned by the strategy
  function rewardsEarned() external returns (uint256);

  // Returns the limit of deposit allowed in the strategy
  function limitOfDeposit() external returns (uint256);

  // Returns the status of deposit in the strategy
  function depositStatus() external returns (bool);

  // Returns the status of withdrawal in the strategy
  function withdrawStatus() external returns (bool);
}
