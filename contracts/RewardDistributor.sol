//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";

import "./Ownable.sol";
import "./StakingPool.sol";

interface IRewardRecipient {
  function setRewardRate(uint256 rewardRate) external;
}

contract RewardDistributor is Ownable {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  IERC20 public rewardToken;

  EnumerableSet.AddressSet internal recipients;

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
    require(recipients.contains(_recipient), "recipient has not been added");

    IRewardRecipient(_recipient).setRewardRate(_rewardRate);
  }

  function addRecipient(address _recipient) public onlyOwner {
    if (recipients.add(_recipient)) {
      rewardToken.safeApprove(_recipient, uint256(-1));
      emit RewardRecipientAdded(_recipient);
    }
  }

  /**
   * @notice This should not be a normal operation
   * To stop the reward distribution of a specific recipient, just set the reward to 0.
   * Removing receipient means no reward can be claimed from it.
   */
  function removeRecipient(address _recipient) external onlyOwner {
    if (recipients.remove(_recipient)) {
      rewardToken.safeApprove(_recipient, 0);
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

  /**
   * @notice Return all of the Staking Pool recipients
   * @return _allRecipients The list of Staking Pool recipients addresses
   */
  function getAllRecipients()
    public
    view
    returns (address[] memory _allRecipients)
  {
    EnumerableSet.AddressSet storage _recipients = recipients;

    uint256 _len = _recipients.length();
    _allRecipients = new address[](_len);
    for (uint256 i = 0; i < _len; i++) {
      _allRecipients[i] = _recipients.at(i);
    }
  }
}
