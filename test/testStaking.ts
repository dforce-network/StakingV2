import { ethers, waffle, network } from "hardhat";
import { Signer, Contract, BigNumber, utils } from "ethers";
import { expect } from "chai";
const { createFixtureLoader, provider } = waffle;

// Use ethers provider instead of waffle's default MockProvider
const loadFixture = createFixtureLoader([], provider);

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
  ).deploy(lp.address, rewardToken.address);
  await pool.deployed();

  return { lp, pool };
}

async function newStakingPool(index: number, rewardDistributor: Contract) {
  const nameAndSymbol = "LP" + index;
  const lp = await deployERC20(nameAndSymbol, nameAndSymbol);

  const StakingPool = await ethers.getContractFactory("StakingPool");

  const tx = await rewardDistributor.newStakingPoolAndSetRewardRate(
    lp.address,
    0
  );

  const receipt = await tx.wait();
  // const event = receipt.events[2];

  const pool = StakingPool.attach(receipt.events[2].args.recipient);

  return { lp, pool };
}

async function deployStakingPools(
  rewardToken: Contract,
  rewardDistributor: Contract,
  poolNum: number = 3
) {
  let lpsAndPools = await Promise.all(
    [...Array(poolNum).keys()].map(async (index) =>
      newStakingPool(index, rewardDistributor)
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
  const amount = utils.parseEther("10000");

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

  const rewardRate = utils.parseEther("10000");

  before(async function () {
    // Only 5 accounts will stake
    accounts = (await ethers.getSigners()).slice(0, 4);

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
      rewardDistributor.address,
      utils.parseEther("100000000")
    );
  });

  describe("RewardDistributor", function () {
    // Staking pools are already added as recipients when newStakingPoolAndSetRewardRate is called

    // it("should be able to add recipients", async function () {
    //   const rewardRate = utils.parseEther("10000");
    //   for (const pool of pools) {
    //     await rewardDistributor.addRecipientAndSetRewardRate(
    //       pool.address,
    //       rewardRate
    //     );

    //     expect(await pool.rewardRate()).to.equal(rewardRate);
    //   }
    // });

    it("should be able to set recipients' reward rate", async function () {
      for (const pool of pools) {
        await rewardDistributor.setRecipientRewardRate(
          pool.address,
          rewardRate
        );

        expect(await pool.rewardRate()).to.equal(rewardRate);
      }
    });

    it("should fail to set non-recipient's reward rate", async function () {
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

    it("should be able to get all recipients", async function () {
      // To use [...] to shallow copy the addresses and then sort
      // calling sort on the addresses seems change the orders of the original pool contract
      const poolAddresses = [...pools.map((v) => v.address)].sort();
      let allRecipients = [
        ...(await rewardDistributor.getAllRecipients()),
      ].sort();

      // console.log(poolAddresses);
      // console.log(allRecipients);

      expect(allRecipients).to.eql(poolAddresses);
    });
  });

  describe("Staking Pool", function () {
    let lastUpdateTime: number;

    async function miningBlock() {
      await network.provider.send("evm_mine");
    }

    async function increaseTime(time: number) {
      await network.provider.request({
        method: "evm_increaseTime",
        params: [time],
      });
    }

    async function getCurrentTimestamp() {
      const blockNumber = await provider.getBlockNumber();
      const block = await provider.getBlock(blockNumber);

      return block.timestamp;
    }

    before(async function () {
      // Approve all lp token for all accounts
      for (const { lp, pool } of lpsAndPools) {
        for (const account of accounts) {
          await lp
            .connect(account)
            .approve(pool.address, ethers.constants.MaxUint256);
        }
      }

      // Stop automine to allow accounts to stake/withdraw at the same block
      await network.provider.send("evm_setAutomine", [false]);
    });

    after(async function () {
      await network.provider.send("evm_setAutomine", [true]);
    });

    it("should be able to stake", async function () {
      const { lp, pool } = lpsAndPools[0];
      let amount = utils.parseEther("10");

      const txs = await Promise.all(
        accounts.map((account) => pool.connect(account).stake(amount))
      );

      await miningBlock();

      const receipts = await Promise.all(txs.map((tx) => tx.wait()));

      // Assuming all txs are in the same block
      lastUpdateTime = await getCurrentTimestamp();
    });

    it("check accounts earned", async function () {
      const { lp, pool } = lpsAndPools[0];

      await increaseTime(3600);
      await miningBlock();

      const rewardRate = await pool.rewardRate();
      const timeElapsed = (await getCurrentTimestamp()) - lastUpdateTime;
      const totalReward = rewardRate.mul(timeElapsed);

      const earned = await Promise.all(
        addresses.map(async (address) => await pool.earned(address))
      );

      // console.log(earned.map((v) => v.toString()));

      expect(earned.reduce((a, v) => a.add(v))).to.equal(totalReward);
    });

    it("should be able to withdraw", async function () {
      const { lp, pool } = lpsAndPools[0];

      const txs = await Promise.all(
        accounts.map(async (account) => {
          const address = await account.getAddress();
          let balance = await pool.balanceOf(address);
          let amount = balance.div(2);
          return pool.connect(account).withdraw(amount);
        })
      );

      await miningBlock();

      const receipts = await Promise.all(txs.map((tx) => tx.wait()));
    });

    it("should be able to get reward", async function () {
      const { lp, pool } = lpsAndPools[0];
      const amount = utils.parseEther("10");

      await increaseTime(3600);
      await miningBlock();

      let earned = await Promise.all(
        addresses.map(async (address) => {
          return pool.earned(address);
        })
      );

      const rewardBalancesBefore = await Promise.all(
        addresses.map(async (address) => {
          return rewardToken.balanceOf(address);
        })
      );

      // Increase timestamp of 1s
      await increaseTime(1);
      earned = earned.map((v) => v.add(rewardRate.div(accounts.length)));

      const txs = await Promise.all(
        accounts.map(async (account) => {
          return pool.connect(account).getReward();
        })
      );
      await miningBlock();
      await Promise.all(txs.map((tx) => tx.wait()));

      const rewardBalancesAfter = await Promise.all(
        addresses.map(async (address) => {
          return rewardToken.balanceOf(address);
        })
      );

      const rewards = rewardBalancesAfter.map((v, i) =>
        v.sub(rewardBalancesBefore[i])
      );

      // console.log(earned.map((v) => v.toString()));
      // console.log(rewards.map((v) => v.toString()));

      expect(rewards).to.deep.equal(earned);
    });
  });
});
