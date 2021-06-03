import { ethers, waffle, network } from "hardhat";
import { Signer, Contract, BigNumber, utils } from "ethers";
import { expect } from "chai";
const { createFixtureLoader, provider } = waffle;

const {
  miningBlock,
  increaseTime,
  getCurrentTimestamp,
  deployERC20,
  deployRewardDistributor,
  deployStakingPool,
  deployStakingPools,
} = require("./utils");

// Use ethers provider instead of waffle's default MockProvider
const loadFixture = createFixtureLoader([], provider);

async function fixtureRewardDistributor() {
  const rewardToken = await deployERC20("DF", "DF");
  const rewardDistributor = await deployRewardDistributor(rewardToken);

  return { rewardToken, rewardDistributor };
}

async function fixtureDefault() {
  const { rewardToken, rewardDistributor } = await loadFixture(
    fixtureRewardDistributor
  );

  const lpsAndPools = await deployStakingPools(
    rewardToken,
    rewardDistributor,
    (await getCurrentTimestamp()) + 3600
  );

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
  let startTime: number;

  const rewardRate = utils.parseEther("10000");
  const intialRewardTransfered = utils.parseEther("100000000");

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
    await rewardToken.mint(rewardDistributor.address, intialRewardTransfered);
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
        rewardDistributor,
        (await getCurrentTimestamp()) + 3600
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

    it("should be able to rescue tokens", async function () {
      const poolAddress = pools[0].address;
      const amount = utils.parseEther("200");
      await rewardToken.mint(poolAddress, amount);

      await expect(() =>
        rewardDistributor.rescueStakingPoolTokens(
          poolAddress,
          rewardToken.address,
          amount,
          addresses[1]
        )
      ).to.changeTokenBalance(rewardToken, accounts[1], amount);

      await rewardToken.connect(accounts[1]).transfer(poolAddress, amount);

      await expect(
        pools[0].rescueTokens(rewardToken.address, amount, addresses[1])
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });
  });

  describe("Staking Pool", function () {
    let stakeTime, startTime: number;
    let rewardClaimed: number;

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

    describe("Before start time", function () {
      it("should be able to stake", async function () {
        const { lp, pool } = lpsAndPools[0];
        let amount = utils.parseEther("10");

        const txs = await Promise.all(
          accounts.map((account) => pool.connect(account).stake(amount))
        );

        await miningBlock();

        const receipts = await Promise.all(txs.map((tx) => tx.wait()));

        // Assuming all txs are in the same block
        stakeTime = await getCurrentTimestamp();
        startTime = await pool.startTime();

        expect(stakeTime).lt(startTime);
      });

      it("accounts earned should all be 0", async function () {
        const { lp, pool } = lpsAndPools[0];

        await increaseTime(1000);

        const currentTime = await getCurrentTimestamp();
        expect(currentTime).lt(startTime);

        const earned = await Promise.all(
          addresses.map(async (address) => await pool.earned(address))
        );

        // console.log(earned.map((v) => v.toString()));

        // total reward of all accounts should be 0
        expect(earned.reduce((a, v) => a.add(v))).to.equal(0);
      });

      it("should be able to withdraw and exit", async function () {
        const { lp, pool } = lpsAndPools[0];

        await increaseTime(1000);

        const currentTime = await getCurrentTimestamp();
        expect(currentTime).lt(startTime);

        // Withdraw
        let txs = await Promise.all(
          accounts.map(async (account) => {
            const address = await account.getAddress();
            let balance = await pool.balanceOf(address);
            let amount = balance.div(2);
            return pool.connect(account).withdraw(amount);
          })
        );
        await miningBlock();
        await Promise.all(txs.map((tx) => tx.wait()));

        // Exit
        txs = await Promise.all(
          accounts.map(async (account) => {
            const address = await account.getAddress();
            let balance = await pool.balanceOf(address);
            let amount = balance.div(2);
            return pool.connect(account).exit();
          })
        );
        await miningBlock();
        await Promise.all(txs.map((tx) => tx.wait()));

        // Total rewards should be 0
        const rewardBalances = await Promise.all(
          addresses.map(async (address) => {
            return rewardToken.balanceOf(address);
          })
        );
        expect(rewardBalances.reduce((a, v) => a.add(v))).to.equal(0);
      });

      it("should be able to stake again", async function () {
        const { lp, pool } = lpsAndPools[0];
        let amount = utils.parseEther("10");

        const txs = await Promise.all(
          accounts.map((account) => pool.connect(account).stake(amount))
        );

        await miningBlock();

        const receipts = await Promise.all(txs.map((tx) => tx.wait()));

        // Assuming all txs are in the same block
        stakeTime = await getCurrentTimestamp();
        startTime = await pool.startTime();

        expect(stakeTime).lt(startTime);
      });
      it("reward distributed should be 0", async function () {
        const { lp, pool } = lpsAndPools[0];
        expect(await pool.rewardDistributed()).to.equal(0);
      });
    });

    describe("After start time", function () {
      it("shoud pass the start time", async function () {
        const { lp, pool } = lpsAndPools[0];

        await increaseTime(3600);

        const currentTime = await getCurrentTimestamp();
        startTime = await pool.startTime();
        expect(currentTime).gt(startTime);
      });

      it("check accounts earned after start time", async function () {
        const { lp, pool } = lpsAndPools[0];

        const currentTime = await getCurrentTimestamp();
        const rewardRate = await pool.rewardRate();
        const timeStaked = currentTime - startTime;
        const totalReward = rewardRate.mul(timeStaked);

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

        await Promise.all(txs.map((tx) => tx.wait()));
      });

      it("should be able to get reward", async function () {
        const { lp, pool } = lpsAndPools[0];
        const amount = utils.parseEther("10");

        await increaseTime(3600);

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

        const time1 = await getCurrentTimestamp();

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

        const time2 = await getCurrentTimestamp();
        earned = earned.map((v) =>
          v.add(rewardRate.mul(time2 - time1).div(accounts.length))
        );

        // console.log(earned.map((v) => v.toString()));
        // console.log(rewards.map((v) => v.toString()));

        expect(rewards).to.deep.equal(earned);

        rewardClaimed = rewards.reduce((a, v) => a.add(v));
      });

      it("reward distributed should be correct", async function () {
        const { lp, pool } = lpsAndPools[0];

        await increaseTime(60);

        const newRewardRate = rewardRate.mul(2);
        await rewardDistributor.setRecipientRewardRate(
          pool.address,
          newRewardRate
        );
        await miningBlock();
        const time1 = await getCurrentTimestamp();
        let rewardDistributed = rewardRate.mul(time1 - startTime);

        expect(await pool.rewardDistributed()).to.equal(rewardDistributed);

        await increaseTime(100);
        const time2 = await getCurrentTimestamp();

        rewardDistributed = rewardDistributed.add(
          newRewardRate.mul(time2 - time1)
        );

        expect(await pool.rewardDistributed()).to.equal(rewardDistributed);

        // const rewardRemaining = await rewardToken.balanceOf(
        //   rewardDistributor.address
        // );

        // const rewardPending = rewardDistributed.sub(rewardClaimed);

        // console.log(utils.formatEther(rewardDistributed));
        // console.log(utils.formatEther(rewardClaimed));
        // console.log(utils.formatEther(rewardRemaining));
      });

      it("should be able to exit", async function () {
        const { lp, pool } = lpsAndPools[0];

        const txs = await Promise.all(
          accounts.map(async (account) => {
            const address = await account.getAddress();
            let balance = await pool.balanceOf(address);
            let amount = balance.div(2);
            return pool.connect(account).exit();
          })
        );

        await miningBlock();

        await Promise.all(txs.map((tx) => tx.wait()));
      });
    });
  });
});
