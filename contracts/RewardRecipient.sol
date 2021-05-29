//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Ownable.sol";

abstract contract RewardRecipient is Ownable {
  address public rewardDistributor;

  function setRewardRate(uint256 _rewardRate) external virtual;

  modifier onlyRewardDistributor() {
    require(
      msg.sender == rewardDistributor,
      "Caller is not reward distribution"
    );
    _;
  }

  function setRewardDistributor(address _rewardDistributor) external onlyOwner {
    rewardDistributor = _rewardDistributor;
  }
}
