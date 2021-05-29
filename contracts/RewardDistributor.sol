//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./StakingPool.sol";

interface IRewardRecipient {
  function setRewardRate(uint256 rewardRate) external;
}

contract RewardDistributor is Ownable {
  IERC20 public rewardToken;

  mapping(address => bool) public isRecipient;

  event RewardRecipientAdded(address recipient);
  event RewardRecipientRemoved(address recipient);

  constructor(address _rewardToken) public {
    rewardToken = IERC20(_rewardToken);
  }

  function setRecipientRewardRate(address recipient, uint256 rewardRate)
    public
    onlyOwner
  {
    require(isRecipient[recipient], "recipient has not been added");

    IRewardRecipient(recipient).setRewardRate(rewardRate);
  }

  function transferReward(address to, uint256 value) external {
    require(isRecipient[msg.sender], "recipient has not been added");

    rewardToken.transfer(to, value);
  }

  function addRecipient(address recipient) public onlyOwner {
    if (!isRecipient[recipient]) {
      isRecipient[recipient] = true;
      emit RewardRecipientAdded(recipient);
    }
  }

  /**
   * @notice This should not be a normal operation
   * To stop the reward distribution of a specific recipient, just set the reward to 0.
   * Removing receipient means no reward can be claimed from it.
   */
  function removeRecipient(address recipient) external onlyOwner {
    if (isRecipient[recipient]) {
      isRecipient[recipient] = false;
      emit RewardRecipientRemoved(recipient);
    }
  }

  /**
   * @param recipient The address of staking pool to distribute reward.
   * @param rewardRate The reward amount to distribute per block.
   */
  function addRecipientAndSetRewardRate(address recipient, uint256 rewardRate)
    external
    onlyOwner
  {
    addRecipient(recipient);
    setRecipientRewardRate(recipient, rewardRate);
  }
}
