//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RewardRecipient is Ownable {
  address public rewardDistributor;

  function setRewardRate(uint256 _rewardRate) external virtual;

  modifier onlyRewardDistributor() {
    require(
      _msgSender() == rewardDistributor,
      "Caller is not reward distribution"
    );
    _;
  }

  function setRewardDistributor(address _rewardDistributor) external onlyOwner {
    rewardDistributor = _rewardDistributor;
  }
}
