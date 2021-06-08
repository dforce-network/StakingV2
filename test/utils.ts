import { ethers, waffle, network } from "hardhat";
import { Signer, Contract, BigNumber, utils } from "ethers";
const { provider } = waffle;

async function miningBlock() {
  await network.provider.send("evm_mine");
}

async function increaseTime(time: number) {
  await network.provider.request({
    method: "evm_increaseTime",
    params: [time],
  });
  await miningBlock();
}

async function getCurrentTimestamp() {
  const blockNumber = await provider.getBlockNumber();
  const block = await provider.getBlock(blockNumber);

  return block.timestamp;
}

async function deployERC20(
  name: string,
  symbol: string,
  decimals: number = 18
): Promise<Contract> {
  const token = await (
    await ethers.getContractFactory("Token")
  ).deploy(name, symbol, decimals);

  await token.deployed();

  return token;
}

async function deployRewardDistributor(
  rewardToken: Contract
): Promise<Contract> {
  const rewardDistributor = await (
    await ethers.getContractFactory("RewardDistributor")
  ).deploy(rewardToken.address);

  await rewardDistributor.deployed();

  return rewardDistributor;
}

async function deployStakingPool(
  index: number,
  rewardToken: Contract,
  rewardDistributor: Contract,
  startTime: number
) {
  const nameAndSymbol = "LP" + index;
  const lp = await deployERC20(nameAndSymbol, nameAndSymbol);

  const pool = await (
    await ethers.getContractFactory("StakingPool")
  ).deploy(lp.address, rewardToken.address, startTime);
  await pool.deployed();

  return { lp, pool };
}

async function newStakingPool(
  index: number,
  rewardDistributor: Contract,
  startTime: number
) {
  const nameAndSymbol = "LP" + index;
  const lp = await deployERC20(nameAndSymbol, nameAndSymbol);

  const StakingPool = await ethers.getContractFactory("StakingPool");

  const tx = await rewardDistributor.newStakingPoolAndSetRewardRate(
    lp.address,
    0,
    startTime
  );

  const receipt = await tx.wait();
  // const event = receipt.events[2];

  const pool = StakingPool.attach(receipt.events[2].args.recipient);

  return { lp, pool };
}

async function newStakingPoolWithExternalIncentivizer(
  externalIncentivizer: Contract,
  rewardDistributor: Contract,
  startTime: number
) {
  const lp = (await ethers.getContractFactory("Token")).attach(
    await externalIncentivizer.uni_lp()
  );

  const StakingPoolWithExternalIncentivizer = await ethers.getContractFactory(
    "StakingPoolWithExternalIncentivizer"
  );

  const tx =
    await rewardDistributor.newStakingPoolWithExternalIncentivizerAndSetRewardRate(
      await externalIncentivizer.uni_lp(),
      0,
      startTime,
      externalIncentivizer.address
    );

  const receipt = await tx.wait();
  // const event = receipt.events[2];

  const pool = StakingPoolWithExternalIncentivizer.attach(
    receipt.events[2].args.recipient
  );

  await pool.approveLp();

  return { lp, pool };
}
async function deployStakingPools(
  rewardToken: Contract,
  rewardDistributor: Contract,
  startTime: number,
  poolNum: number = 3
) {
  let lpsAndPools = await Promise.all(
    [...Array(poolNum).keys()].map(async (index) =>
      newStakingPool(index, rewardDistributor, startTime)
    )
  );

  return lpsAndPools;
}

export = {
  miningBlock,
  increaseTime,
  getCurrentTimestamp,
  deployERC20,
  deployRewardDistributor,
  deployStakingPool,
  newStakingPool,
  deployStakingPools,
  newStakingPoolWithExternalIncentivizer,
};
