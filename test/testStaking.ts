import { ethers, waffle } from "hardhat";
import { Signer, Contract, BigNumber } from "ethers";
import { expect } from "chai";
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

async function deployStakingPool(
  index: number,
  rewardToken: Contract,
  rewardDistributor: Contract
) {
  const nameAndSymbol = "LP" + index;
  const lp = await deployERC20(nameAndSymbol, nameAndSymbol);

  const pool = await (
    await ethers.getContractFactory("StakingPool")
  ).deploy(lp.address, rewardToken.address, rewardDistributor.address);
  await pool.deployed();

  return { lp, pool };
}

async function deployStakingPools(
  rewardToken: Contract,
  rewardDistributor: Contract,
  poolNum: number = 3
) {
  let lpsAndPools = await Promise.all(
    [...Array(poolNum).keys()].map(async (index) =>
      deployStakingPool(index, rewardToken, rewardDistributor)
    )
  );

  return lpsAndPools;
}

async function fixtureDefault() {
  const { rewardToken, rewardDistributor } = await loadFixture(
    fixtureRewardDistributor
  );

  const lpsAndPools = await deployStakingPools(rewardToken, rewardDistributor);

  return { rewardToken, rewardDistributor, lpsAndPools };
}

async function distributeLPTokens(lps: Contract[], accounts: string[]) {
  // Assuming decimals of all lps are 18
  const amount = ethers.utils.parseEther("10000");

  for (const lp of lps) {
    for (const account of accounts) {
      await lp.mint(account, amount);
    }
  }
}

describe("Stakinng V2", function () {
  let accounts: Signer[];
  let addresses: string[];
  let rewardToken: Contract;
  let rewardDistributor: Contract;
  let lpsAndPools: { lp: Contract; pool: Contract }[];
  let lps: Contract[];
  let pools: Contract[];

  before(async function () {
    accounts = await ethers.getSigners();
    ({ rewardToken, rewardDistributor, lpsAndPools } = await loadFixture(
      fixtureDefault
    ));

    lps = lpsAndPools.map((pool) => pool.lp);
    pools = lpsAndPools.map((pool) => pool.pool);
    addresses = await Promise.all(
      accounts.map(async (a) => await a.getAddress())
    );

    await distributeLPTokens(lps, addresses);

    // Initial transfer of rewardToken
    await rewardToken.mint(
      rewardToken.address,
      ethers.utils.parseEther("100000000")
    );
  });

  describe("RewardDistributor", function () {
    it("should be able to add recipients", async function () {
      const rewardRate = ethers.utils.parseEther("10000");
      for (const pool of pools) {
        await rewardDistributor.addRecipientAndSetRewardRate(
          pool.address,
          rewardRate
        );

        expect(await pool.rewardRate()).to.equal(rewardRate);
      }
    });

    it("should be able to set recipients' reward rate", async function () {
      const rewardRate = ethers.utils.parseEther("10000");
      for (const pool of pools) {
        await rewardDistributor.setRecipientRewardRate(
          pool.address,
          rewardRate
        );

        expect(await pool.rewardRate()).to.equal(rewardRate);
      }
    });

    it("should fail to set non-recipient's reward rate", async function () {
      const rewardRate = ethers.utils.parseEther("10000");

      // Deploy a new pool has not been added
      const { lp, pool } = await deployStakingPool(
        100,
        rewardToken,
        rewardDistributor
      );

      await expect(
        rewardDistributor.setRecipientRewardRate(pool.address, rewardRate)
      ).to.be.revertedWith("recipient has not been added");

      expect(await pool.rewardRate()).to.equal(0);
    });
  });
});
