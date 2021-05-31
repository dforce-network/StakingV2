import { run, ethers } from "hardhat";
const {
  getCurrentTimestamp,
  deployERC20,
  deployRewardDistributor,
  deployStakingPools,
} = require("../test/utils");

async function main() {
  await run("compile");

  const localStartTime = "01/06/2021 19:30:00";
  console.log("Setting Start Time to\t\t:", localStartTime, "\n");
  const startTime = Date.parse(localStartTime) / 1000;

  const rewardToken = await deployERC20("DF", "DF");
  console.log("DF Address\t\t\t:", rewardToken.address);

  const rewardDistributor = await deployRewardDistributor(rewardToken);
  console.log("RewardDistributor Address\t:", rewardDistributor.address);

  const [{ lp, pool }] = await await deployStakingPools(
    rewardToken,
    rewardDistributor,
    startTime,
    1
  );

  console.log("LP address\t\t\t:", lp.address);
  console.log("Staking Pool address\t\t:", pool.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
