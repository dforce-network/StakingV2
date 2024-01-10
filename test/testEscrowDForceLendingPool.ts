import { ethers, waffle, network } from "hardhat";
import { Signer, Contract, BigNumber, utils } from "ethers";
import { expect } from "chai";

const MAX = ethers.constants.MaxUint256;
const ZERO = ethers.constants.Zero;
const BASE = ethers.constants.WeiPerEther;
const ONE = ethers.constants.One;

const times = 100;
const changeExchangeRate = [true, false];
const changeRewardRate = [true, false];
const actions = [
  "mintAndStake",
  "redeemAndWithdraw",
  "redeemUnderlyingAndWithdraw",
  "getReward",
];

const {
  randomRange,
  increaseTime,
  getCurrentTimestamp,
  deployEscrowDForceLending,
} = require("./utils");

async function start(escrowStakingPool: Contract) {
  const timestamp = utils.parseUnits(
    (await getCurrentTimestamp()).toString(),
    0
  );
  const startTime = await escrowStakingPool.startTime();
  if (startTime.gt(timestamp.add(10))) {
    const time = Number(startTime.sub(timestamp.add(10)).toString());
    await increaseTime(time);
  }
}

async function lockup(escrowStakingPool: Contract) {
  const timestamp = utils.parseUnits(
    (await getCurrentTimestamp()).toString(),
    0
  );
  const freezingTime = await escrowStakingPool.freezingTime();
  if (freezingTime.gt(timestamp)) {
    const time = Number(freezingTime.sub(timestamp).add(ONE).toString());
    await increaseTime(time);
  }
  expect(await escrowStakingPool.currentRewardRate()).to.equal(ZERO);
}

describe("EscrowStakingPool", function () {
  let owner: Signer;
  let escrowAccount: string;
  let accounts: Signer[];
  let addresses: string[];
  let controller: Contract;
  let iETH: Contract;
  let iToken: Contract;
  let underlyingToken: Contract;
  let rewardToken: Contract;
  let EscrowiETHStakingPool: Contract;
  let EscrowiTokenStakingPool: Contract;
  let rewardBalance: any;

  // const rewardRate = utils.parseEther("10000");
  // const intialRewardTransfered = utils.parseEther("100000000");

  async function distributionEnded(escrowStakingPool: Contract) {
    for (let index = 0; index < accounts.length; index++) {
      const sender = accounts[index];
      const reward = await escrowStakingPool.earned(addresses[index]);
      await expect(() =>
        escrowStakingPool.connect(sender).getReward()
      ).to.changeTokenBalances(
        rewardToken,
        [sender, owner, escrowStakingPool],
        [reward, reward.mul(-1), ZERO]
      );
    }
    const rewardDistributed = await escrowStakingPool.rewardDistributed();
    const remainingReward = await rewardToken.balanceOf(
      await owner.getAddress()
    );
    console.log(rewardDistributed.toString());
    console.log(rewardBalance.sub(remainingReward).toString());
  }

  before(async function () {
    const data = await deployEscrowDForceLending();

    owner = data.owner;
    escrowAccount = data.escrowAccount;
    accounts = data.accounts;
    controller = data.controller;
    iETH = data.iETH;
    iToken = data.iToken;
    underlyingToken = data.underlyingToken;
    rewardToken = data.rewardToken;
    EscrowiETHStakingPool = data.EscrowiETHStakingPool;
    EscrowiTokenStakingPool = data.EscrowiTokenStakingPool;

    const amount = utils.parseEther("10000");

    addresses = await Promise.all(
      accounts.map(async (a) => await a.getAddress())
    );

    for (let index = 0; index < accounts.length; index++) {
      addresses[index] = await accounts[index].getAddress();
      await underlyingToken.mint(addresses[index], amount);
      await underlyingToken
        .connect(accounts[index])
        .approve(EscrowiTokenStakingPool.address, MAX);
    }

    const ownerAddr = await owner.getAddress();
    await rewardToken.mint(ownerAddr, utils.parseEther("1000000"));
    await underlyingToken.mint(ownerAddr, utils.parseEther("1000000"));
    await rewardToken.approve(EscrowiETHStakingPool.address, MAX);
    await rewardToken.approve(EscrowiTokenStakingPool.address, MAX);
    rewardBalance = await rewardToken.balanceOf(ownerAddr);
  });

  describe("EscrowiTokenStakingPool", async function () {
    before(async function () {
      rewardBalance = await rewardToken.balanceOf(await owner.getAddress());
    });

    it("test setRewardRate: Not owner, expected revert", async () => {
      const rewardRate = utils.parseEther("1");
      await expect(
        EscrowiTokenStakingPool.connect(accounts[0]).setRewardRate(rewardRate)
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });

    it("test setRewardRate: is owner, success", async () => {
      const rewardRate = utils.parseEther("1");
      await EscrowiTokenStakingPool.setRewardRate(rewardRate);

      expect(await EscrowiTokenStakingPool.rewardRate()).to.equal(rewardRate);
    });

    it("test escrowTransfer: Not owner, expected revert", async () => {
      await expect(
        EscrowiTokenStakingPool.connect(accounts[0]).escrowTransfer()
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });

    it("test escrowTransfer: is owner, not expired, expected revert", async () => {
      await expect(EscrowiTokenStakingPool.escrowTransfer()).to.be.revertedWith(
        "Freezing time has not expired"
      );
    });

    it("test escrowUnderlyingTransfer: Not owner, expected revert", async () => {
      await expect(
        EscrowiTokenStakingPool.connect(accounts[0]).escrowUnderlyingTransfer()
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });

    it("test escrowUnderlyingTransfer: is owner, not expired, expected revert", async () => {
      await expect(
        EscrowiTokenStakingPool.escrowUnderlyingTransfer()
      ).to.be.revertedWith("Freezing time has not expired");
    });

    //

    it("test stake: expected revert", async () => {
      const amount = utils.parseEther("1");
      await expect(
        EscrowiTokenStakingPool.connect(accounts[0]).stake(amount)
      ).to.be.revertedWith("");
    });

    it("test withdraw: expected revert", async () => {
      const amount = utils.parseEther("1");
      await expect(
        EscrowiTokenStakingPool.connect(accounts[0]).withdraw(amount)
      ).to.be.revertedWith("");
    });

    it("test exit: expected revert", async () => {
      const amount = utils.parseEther("1");
      await expect(
        EscrowiTokenStakingPool.connect(accounts[0]).exit()
      ).to.be.revertedWith("");
    });

    it("test mintAndStake: insufficient allowance, expected revert", async () => {
      const sender = accounts[0];
      const amount = utils.parseEther("1");
      await underlyingToken
        .connect(sender)
        .approve(EscrowiTokenStakingPool.address, amount.sub(1));
      await expect(
        EscrowiTokenStakingPool.connect(sender).mintAndStake(amount)
      ).to.be.revertedWith("ERC20: transfer amount exceeds allowance");

      await underlyingToken
        .connect(sender)
        .approve(EscrowiTokenStakingPool.address, MAX);
    });

    it("test start: success", async () => {
      await start(EscrowiTokenStakingPool);
    });

    for (let index = 1; index <= times; index++) {
      const action = actions[randomRange(0, actions.length - 1)];
      it(`test random test ${index} : ${action}`, async () => {
        if (changeExchangeRate[randomRange(0, actions.length - 1)]) {
          await underlyingToken.transfer(iToken.address, BASE);
        }
        if (changeRewardRate[randomRange(0, actions.length - 1)]) {
          const rewardRate = utils.parseEther(randomRange(1, 10).toString());
          await EscrowiTokenStakingPool.setRewardRate(
            rewardRate.div(utils.parseUnits("2", 0))
          );
        }
        const accountIndex = randomRange(0, accounts.length - 1);
        const sender = accounts[accountIndex];
        const stakingPoolBalance = await iToken.balanceOf(
          EscrowiTokenStakingPool.address
        );
        const totalSupply = await EscrowiTokenStakingPool.totalSupply();
        const accountBalance = await EscrowiTokenStakingPool.balanceOf(
          addresses[accountIndex]
        );
        const exchangeRate = await iToken.callStatic.exchangeRateCurrent();

        expect(stakingPoolBalance).to.equal(totalSupply);
        switch (action) {
          case "mintAndStake":
            {
              const balance = await underlyingToken.balanceOf(
                addresses[accountIndex]
              );
              const stakeAmount = balance.div(utils.parseUnits("2", 0));

              await expect(() =>
                EscrowiTokenStakingPool.connect(sender).mintAndStake(
                  stakeAmount
                )
              ).to.changeTokenBalances(
                underlyingToken,
                [sender, iToken, EscrowiTokenStakingPool],
                [stakeAmount.mul(-1), stakeAmount, ZERO]
              );

              const iTokenAmount = stakeAmount.mul(BASE).div(exchangeRate);
              expect(totalSupply.add(iTokenAmount)).to.equal(
                await EscrowiTokenStakingPool.totalSupply()
              );
              expect(totalSupply.add(iTokenAmount)).to.equal(
                await iToken.balanceOf(EscrowiTokenStakingPool.address)
              );
              expect(accountBalance.add(iTokenAmount)).to.equal(
                await EscrowiTokenStakingPool.balanceOf(addresses[accountIndex])
              );
            }
            break;
          case "redeemAndWithdraw":
            {
              const balance = await EscrowiTokenStakingPool.balanceOf(
                addresses[accountIndex]
              );
              const withdrawAmount = balance.div(utils.parseUnits("2", 0));

              const accountUnderlyingBalance = await underlyingToken.balanceOf(
                addresses[accountIndex]
              );

              const iTokenUnderlyingBalance = await underlyingToken.balanceOf(
                iToken.address
              );

              await expect(() =>
                EscrowiTokenStakingPool.connect(sender).redeemAndWithdraw(
                  withdrawAmount
                )
              ).to.changeTokenBalances(
                iToken,
                [sender, iToken, EscrowiTokenStakingPool],
                [ZERO, ZERO, withdrawAmount.mul(-1)]
              );
              const underlyingAmount = withdrawAmount
                .mul(exchangeRate)
                .div(BASE);

              expect(accountUnderlyingBalance.add(underlyingAmount)).to.equal(
                await underlyingToken.balanceOf(addresses[accountIndex])
              );
              expect(iTokenUnderlyingBalance.sub(underlyingAmount)).to.equal(
                await underlyingToken.balanceOf(iToken.address)
              );
              expect(totalSupply.sub(withdrawAmount)).to.equal(
                await EscrowiTokenStakingPool.totalSupply()
              );
              expect(totalSupply.sub(withdrawAmount)).to.equal(
                await iToken.balanceOf(EscrowiTokenStakingPool.address)
              );
              expect(accountBalance.sub(withdrawAmount)).to.equal(
                await EscrowiTokenStakingPool.balanceOf(addresses[accountIndex])
              );
            }
            break;
          case "redeemUnderlyingAndWithdraw":
            {
              const balance =
                await EscrowiTokenStakingPool.callStatic.balanceOfUnderlying(
                  addresses[accountIndex]
                );
              const withdrawAmount = balance.div(utils.parseUnits("2", 0));

              await expect(() =>
                EscrowiTokenStakingPool.connect(
                  sender
                ).redeemUnderlyingAndWithdraw(withdrawAmount)
              ).to.changeTokenBalances(
                underlyingToken,
                [sender, iToken, EscrowiTokenStakingPool],
                [withdrawAmount, withdrawAmount.mul(-1), ZERO]
              );
              const iTokenAmount = withdrawAmount
                .mul(BASE)
                .add(exchangeRate.sub(1))
                .div(exchangeRate);
              expect(totalSupply.sub(iTokenAmount)).to.equal(
                await EscrowiTokenStakingPool.totalSupply()
              );
              expect(totalSupply.sub(iTokenAmount)).to.equal(
                await iToken.balanceOf(EscrowiTokenStakingPool.address)
              );
              expect(accountBalance.sub(iTokenAmount)).to.equal(
                await EscrowiTokenStakingPool.balanceOf(addresses[accountIndex])
              );
            }
            break;
          case "getReward":
            await EscrowiTokenStakingPool.connect(sender).getReward();
            break;

          default:
            break;
        }
      });
    }

    it("test lockup: success", async () => {
      await lockup(EscrowiTokenStakingPool);
    });

    it("test escrowUnderlyingTransfer: is owner, expired, success", async () => {
      await EscrowiTokenStakingPool.escrowUnderlyingTransfer();
    });

    it("test escrowTransfer: is owner, expired, success", async () => {
      await EscrowiTokenStakingPool.escrowTransfer();
    });

    it("test mintAndStake: expired, expected revert", async () => {
      const sender = accounts[0];
      const amount = await underlyingToken.balanceOf(addresses[0]);
      await expect(
        EscrowiTokenStakingPool.connect(sender).mintAndStake(amount)
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test redeemAndWithdraw: expired, expected revert", async () => {
      const sender = accounts[0];
      const amount = await EscrowiTokenStakingPool.balanceOf(addresses[0]);
      await expect(
        EscrowiTokenStakingPool.connect(sender).redeemAndWithdraw(amount)
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test redeemUnderlyingAndWithdraw: expired, expected revert", async () => {
      const sender = accounts[0];
      const amount =
        await EscrowiTokenStakingPool.callStatic.balanceOfUnderlying(
          addresses[0]
        );
      await expect(
        EscrowiTokenStakingPool.connect(sender).redeemUnderlyingAndWithdraw(
          amount
        )
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test exitUnderlying: expired, expected revert", async () => {
      const sender = accounts[0];
      await expect(
        EscrowiTokenStakingPool.connect(sender).exitUnderlying()
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test reward: expired, success", async () => {
      await distributionEnded(EscrowiTokenStakingPool);
    });
  });

  describe("EscrowiETHStakingPool", async function () {
    before(async function () {
      rewardBalance = await rewardToken.balanceOf(await owner.getAddress());
    });

    it("test setRewardRate: Not owner, expected revert", async () => {
      const rewardRate = utils.parseEther("1");
      await expect(
        EscrowiETHStakingPool.connect(accounts[0]).setRewardRate(rewardRate)
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });

    it("test setRewardRate: is owner, success", async () => {
      const rewardRate = utils.parseEther("1");
      await EscrowiETHStakingPool.setRewardRate(rewardRate);

      expect(await EscrowiETHStakingPool.rewardRate()).to.equal(rewardRate);
    });

    it("test escrowTransfer: Not owner, expected revert", async () => {
      await expect(
        EscrowiETHStakingPool.connect(accounts[0]).escrowTransfer()
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });

    it("test escrowTransfer: is owner, not expired, expected revert", async () => {
      await expect(EscrowiETHStakingPool.escrowTransfer()).to.be.revertedWith(
        "Freezing time has not expired"
      );
    });

    it("test escrowUnderlyingTransfer: Not owner, expected revert", async () => {
      await expect(
        EscrowiETHStakingPool.connect(accounts[0]).escrowUnderlyingTransfer()
      ).to.be.revertedWith("onlyOwner: caller is not the owner");
    });

    it("test escrowUnderlyingTransfer: is owner, not expired, expected revert", async () => {
      await expect(
        EscrowiETHStakingPool.escrowUnderlyingTransfer()
      ).to.be.revertedWith("Freezing time has not expired");
    });

    it("test stake: expected revert", async () => {
      const amount = utils.parseEther("1");
      await expect(
        EscrowiETHStakingPool.connect(accounts[0]).stake(amount)
      ).to.be.revertedWith("");
    });

    it("test withdraw: expected revert", async () => {
      const amount = utils.parseEther("1");
      await expect(
        EscrowiETHStakingPool.connect(accounts[0]).withdraw(amount)
      ).to.be.revertedWith("");
    });

    it("test exit: expected revert", async () => {
      await expect(
        EscrowiETHStakingPool.connect(accounts[0]).exit()
      ).to.be.revertedWith("");
    });

    it("test start: success", async () => {
      await start(EscrowiETHStakingPool);
    });

    for (let index = 1; index <= times; index++) {
      const action = actions[randomRange(0, actions.length - 1)];
      it(`test random test ${index} : ${action}`, async () => {
        if (changeExchangeRate[randomRange(0, actions.length - 1)]) {
          await owner.sendTransaction({
            to: iETH.address,
            value: BASE,
          });
        }
        if (changeRewardRate[randomRange(0, actions.length - 1)]) {
          const rewardRate = utils.parseEther(randomRange(1, 10).toString());
          await EscrowiETHStakingPool.setRewardRate(
            rewardRate.div(utils.parseUnits("2", 0))
          );
        }
        const accountIndex = randomRange(0, accounts.length - 1);
        const sender = accounts[accountIndex];
        const stakingPoolBalance = await iETH.balanceOf(
          EscrowiETHStakingPool.address
        );
        const totalSupply = await EscrowiETHStakingPool.totalSupply();
        const accountBalance = await EscrowiETHStakingPool.balanceOf(
          addresses[accountIndex]
        );
        const exchangeRate = await iETH.callStatic.exchangeRateCurrent();

        expect(stakingPoolBalance).to.equal(totalSupply);
        switch (action) {
          case "mintAndStake":
            {
              const balance = await sender.getBalance();
              const stakeAmount = balance.div(utils.parseUnits("2", 0));

              await expect(() =>
                EscrowiETHStakingPool.connect(sender).mintAndStake({
                  value: stakeAmount,
                })
              ).to.changeEtherBalances(
                [sender, iETH, EscrowiETHStakingPool],
                [stakeAmount.mul(-1), stakeAmount, ZERO]
              );

              const iETHAmount = stakeAmount.mul(BASE).div(exchangeRate);
              expect(totalSupply.add(iETHAmount)).to.equal(
                await EscrowiETHStakingPool.totalSupply()
              );
              expect(totalSupply.add(iETHAmount)).to.equal(
                await iETH.balanceOf(EscrowiETHStakingPool.address)
              );
              expect(accountBalance.add(iETHAmount)).to.equal(
                await EscrowiETHStakingPool.balanceOf(addresses[accountIndex])
              );
            }
            break;
          case "redeemAndWithdraw":
            {
              const balance = await EscrowiETHStakingPool.balanceOf(
                addresses[accountIndex]
              );
              const withdrawAmount = balance.div(utils.parseUnits("2", 0));

              const underlyingAmount = withdrawAmount
                .mul(exchangeRate)
                .div(BASE);

              await expect(() =>
                EscrowiETHStakingPool.connect(sender).redeemAndWithdraw(
                  withdrawAmount
                )
              ).to.changeEtherBalances(
                [sender, iETH, EscrowiETHStakingPool],
                [underlyingAmount, underlyingAmount.mul(-1), ZERO]
              );
              expect(totalSupply.sub(withdrawAmount)).to.equal(
                await EscrowiETHStakingPool.totalSupply()
              );
              expect(totalSupply.sub(withdrawAmount)).to.equal(
                await iETH.balanceOf(EscrowiETHStakingPool.address)
              );
              expect(accountBalance.sub(withdrawAmount)).to.equal(
                await EscrowiETHStakingPool.balanceOf(addresses[accountIndex])
              );
            }
            break;
          case "redeemUnderlyingAndWithdraw":
            {
              const balance =
                await EscrowiETHStakingPool.callStatic.balanceOfUnderlying(
                  addresses[accountIndex]
                );
              const withdrawAmount = balance.div(utils.parseUnits("2", 0));

              await expect(() =>
                EscrowiETHStakingPool.connect(
                  sender
                ).redeemUnderlyingAndWithdraw(withdrawAmount)
              ).to.changeEtherBalances(
                [sender, iETH, EscrowiETHStakingPool],
                [withdrawAmount, withdrawAmount.mul(-1), ZERO]
              );
              const iETHAmount = withdrawAmount
                .mul(BASE)
                .add(exchangeRate.sub(1))
                .div(exchangeRate);
              expect(totalSupply.sub(iETHAmount)).to.equal(
                await EscrowiETHStakingPool.totalSupply()
              );
              expect(totalSupply.sub(iETHAmount)).to.equal(
                await iETH.balanceOf(EscrowiETHStakingPool.address)
              );
              expect(accountBalance.sub(iETHAmount)).to.equal(
                await EscrowiETHStakingPool.balanceOf(addresses[accountIndex])
              );
            }
            break;
          case "getReward":
            await EscrowiETHStakingPool.connect(sender).getReward();
            break;

          default:
            break;
        }
      });
    }

    it("test lockup: success", async () => {
      await lockup(EscrowiETHStakingPool);
    });

    it("test escrowUnderlyingTransfer: is owner, expired, success", async () => {
      await EscrowiETHStakingPool.escrowUnderlyingTransfer();
    });

    it("test escrowTransfer: is owner, expired, success", async () => {
      await EscrowiETHStakingPool.escrowTransfer();
    });

    it("test mintAndStake: expired, expected revert", async () => {
      const sender = accounts[0];
      const amount = await sender.getBalance();
      await expect(
        EscrowiETHStakingPool.connect(sender).mintAndStake({
          value: amount.div(utils.parseUnits("2", 0)),
        })
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test redeemAndWithdraw: expired, expected revert", async () => {
      const sender = accounts[0];
      const amount = await EscrowiETHStakingPool.balanceOf(addresses[0]);
      await expect(
        EscrowiETHStakingPool.connect(sender).redeemAndWithdraw(amount)
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test redeemUnderlyingAndWithdraw: expired, expected revert", async () => {
      const sender = accounts[0];
      const amount = await EscrowiETHStakingPool.callStatic.balanceOfUnderlying(
        addresses[0]
      );
      await expect(
        EscrowiETHStakingPool.connect(sender).redeemUnderlyingAndWithdraw(
          amount
        )
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test exitUnderlying: expired, expected revert", async () => {
      const sender = accounts[0];
      await expect(
        EscrowiETHStakingPool.connect(sender).exitUnderlying()
      ).to.be.revertedWith("Freezing time has entered");
    });

    it("test reward: expired, success", async () => {
      await distributionEnded(EscrowiETHStakingPool);
    });
  });
});
