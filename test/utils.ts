import { ethers, waffle, network } from "hardhat";
import { Signer, Contract, BigNumber, utils } from "ethers";
const { provider } = waffle;

function randomRange(min: number, max: number) {
  return Math.floor(Math.random() * (max - min)) + min;
}

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

async function deployEscrowDForceLending() {
  const controller = await (
    await ethers.getContractFactory("Controller")
  ).deploy();
  await controller.deployed();

  const iETH = await (
    await ethers.getContractFactory("iETH")
  ).deploy(controller.address);
  await iETH.deployed();

  const underlyingName = "underlying Token Name";
  const underlyingSymbol = "underlyingSymbol";
  const underlyingToken = await deployERC20(underlyingName, underlyingSymbol);

  const iToken = await (
    await ethers.getContractFactory("iToken")
  ).deploy(controller.address, underlyingToken.address);
  await iToken.deployed();

  const rewardName = "reward Token Name";
  const rewardSymbol = "rewardSymbol";
  const rewardToken = await deployERC20(rewardName, rewardSymbol);

  const timestamp = await getCurrentTimestamp();
  const startTime = timestamp + 3600;
  const freezingTime = startTime + 3600;

  const [owner, ...accounts] = await ethers.getSigners();

  const escrowAccount = await owner.getAddress();

  const EscrowiTokenStakingPool = await (
    await ethers.getContractFactory("EscrowiTokenStakingPool")
  ).deploy(
    iToken.address,
    rewardToken.address,
    startTime,
    freezingTime,
    escrowAccount
  );
  await EscrowiTokenStakingPool.deployed();

  const EscrowiETHStakingPool = await (
    await ethers.getContractFactory("EscrowiETHStakingPool")
  ).deploy(
    iETH.address,
    rewardToken.address,
    startTime + 86400,
    freezingTime + 86400,
    escrowAccount
  );
  await EscrowiETHStakingPool.deployed();

  return {
    owner,
    escrowAccount,
    accounts,
    controller,
    iETH,
    iToken,
    underlyingToken,
    rewardToken,
    EscrowiTokenStakingPool,
    EscrowiETHStakingPool,
  };
}

export = {
  randomRange,
  miningBlock,
  increaseTime,
  getCurrentTimestamp,
  deployERC20,
  deployRewardDistributor,
  deployStakingPool,
  newStakingPool,
  deployStakingPools,
  deployEscrowDForceLending,
};
