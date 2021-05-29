//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Ownable.sol";

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
    __Ownable_init();
    rewardToken = IERC20(_rewardToken);
  }

  function setRecipientRewardRate(address _recipient, uint256 _rewardRate)
    public
    onlyOwner
  {
    require(isRecipient[_recipient], "recipient has not been added");

    IRewardRecipient(_recipient).setRewardRate(_rewardRate);
  }

  function transferReward(address to, uint256 value) external {
    require(isRecipient[msg.sender], "recipient has not been added");

    rewardToken.transfer(to, value);
  }

  function addRecipient(address _recipient) public onlyOwner {
    if (!isRecipient[_recipient]) {
      isRecipient[_recipient] = true;
      emit RewardRecipientAdded(_recipient);
    }
  }

  /**
   * @notice This should not be a normal operation
   * To stop the reward distribution of a specific recipient, just set the reward to 0.
   * Removing receipient means no reward can be claimed from it.
   */
  function removeRecipient(address _recipient) external onlyOwner {
    if (isRecipient[_recipient]) {
      isRecipient[_recipient] = false;
      emit RewardRecipientRemoved(_recipient);
    }
  }

  /**
   * @param _recipient The address of staking pool to distribute reward.
   * @param _rewardRate The reward amount to distribute per block.
   */
  function addRecipientAndSetRewardRate(address _recipient, uint256 _rewardRate)
    external
    onlyOwner
  {
    addRecipient(_recipient);
    setRecipientRewardRate(_recipient, _rewardRate);
  }

  /**
   * @param _lpToken The address of LP token to stake in the new staking pool.
   * @param _rewardRate The reward amount to distribute per block.
   */
  function newStakingPoolAndSetRewardRate(address _lpToken, uint256 _rewardRate)
    external
    onlyOwner
    returns (address _newStakingPool)
  {
    _newStakingPool = address(new StakingPool(_lpToken, address(rewardToken)));
    addRecipient(_newStakingPool);
    setRecipientRewardRate(_newStakingPool, _rewardRate);
  }
}
