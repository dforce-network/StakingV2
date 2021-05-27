import { ethers, waffle } from "hardhat";
import { Signer, Contract } from "ethers";
const { createFixtureLoader } = waffle;

// Use ethers provider instead of waffle's default MockProvider
const loadFixture = createFixtureLoader([], waffle.provider);

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

async function fixtureRewardDistributor() {
  const rewardToken = await deployERC20("DF", "DF");
  const rewardDistributor = await deployRewardDistributor(rewardToken);

  return { rewardToken, rewardDistributor };
}

async function deployStakingPool(index: number, rewardToken: Contract) {
  const nameAndSymbol = "LP" + index;
  const lp = await deployERC20(nameAndSymbol, nameAndSymbol);

  const pool = await (
    await ethers.getContractFactory("StakingPool")
  ).deploy(lp.address, rewardToken.address);
  await pool.deployed();

  return { lp, pool };
}

async function deployStakingPools(rewardToken: Contract, poolNum: number = 3) {
  let pools = await Promise.all(
    [...Array(poolNum).keys()].map(async (index) =>
      deployStakingPool(index, rewardToken)
    )
  );

  return pools;
}

async function fixtureDefault() {
  const { rewardToken, rewardDistributor } = await loadFixture(
    fixtureRewardDistributor
  );

  const pools = await deployStakingPools(rewardToken);

  return { rewardToken, rewardDistributor, pools };
}

describe("Stakinng V2", function () {
  let accounts: Signer[];
  let rewardToken: Contract;
  let rewardDistributor: Contract;
  let pools: { lp: Contract; pool: Contract }[];

  beforeEach(async function () {
    accounts = await ethers.getSigners();
    ({ rewardToken, rewardDistributor, pools } = await loadFixture(
      fixtureDefault
    ));
  });

  it("should do something right", async function () {
    // Do something with the accounts
    console.log(pools);
  });
});
