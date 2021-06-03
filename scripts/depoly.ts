import { Contract } from "@ethersproject/contracts";
import { writeFileSync, readFileSync, existsSync } from "fs";
import { run, ethers, network } from "hardhat";
const {
  getCurrentTimestamp,
  deployERC20,
  deployRewardDistributor,
  deployStakingPools,
  newStakingPool,
} = require("../test/utils");

const reset = false;

async function main() {
  await run("compile");

  const localStartTime = "06/01/2021 10:30:00";
  const startTime = Date.parse(localStartTime) / 1000;

  const deploymentFile = network.name + ".json";

  let deployment: any = {};
  let rewardToken, rewardDistributor: Contract;

  if (existsSync(deploymentFile) && !reset && network.name !== "hardhat") {
    deployment = JSON.parse(String(readFileSync(deploymentFile)));

    rewardToken = (await ethers.getContractFactory("Token")).attach(
      deployment.DF
    );
    rewardDistributor = (
      await ethers.getContractFactory("RewardDistributor")
    ).attach(deployment.RewardDistributor);

    // Append 1 pool
    const { lp, pool } = await newStakingPool(
      deployment.Pools.length,
      rewardDistributor,
      startTime
    );
    deployment["Pools"].push({ lp: lp.address, pool: pool.address });
  } else {
    const rewardToken = await deployERC20("DF", "DF");
    deployment["DF"] = rewardToken.address;

    const rewardDistributor = await deployRewardDistributor(rewardToken);
    deployment["RewardDistributor"] = rewardDistributor.address;

    // Only deploy 1 pool by default
    let pools = [];
    const [{ lp, pool }] = await deployStakingPools(
      rewardToken,
      rewardDistributor,
      startTime,
      1
    );
    pools.push({ lp: lp.address, pool: pool.address });
    deployment["Pools"] = pools;
  }

  writeFileSync(deploymentFile, JSON.stringify(deployment, null, 2));

  console.log("Setting Start Time to\t\t:", localStartTime, "\n");
  console.log("DF Address\t\t\t:", deployment.DF);
  console.log("RewardDistributor Address\t:", deployment.RewardDistributor);
  deployment.Pools.forEach((element: any, index: number) => {
    console.log(`LP${index} address\t\t\t:`, element.lp);
    console.log(`Staking Pool ${index} address\t\t:`, element.pool);
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
