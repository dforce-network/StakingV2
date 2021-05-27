import { ethers, waffle } from "hardhat";
import { Signer, Contract } from "ethers";
const { createFixtureLoader } = waffle;

// Use ethers provider instead of waffle's default MockProvider
const loadFixture = createFixtureLoader([], waffle.provider);

describe("Stakinng V2", function () {
  let accounts: Signer[];
  let rewardDistributor: Contract;
  let pools: Contract[];

  beforeEach(async function () {
    accounts = await ethers.getSigners();
  });

  it("should do something right", async function () {
    // Do something with the accounts
  });
});
