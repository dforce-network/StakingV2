/// TODO: README.md
/// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
/// Please modify the block number when fork
/// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


// Right click on the script name and hit "Run" to execute
(async () => {
    try {
        console.log("Running deployWithEthers script...");

        const contractName = "RewardDistributor"; // Change this for other contract
        const stakingContractName = "StakingPool";
        let tx;
        let metadata, stakingMetadata;
        let signer;

        // Note that the script needs the ABI which is generated from the compilation artifact.
        // Make sure contract is compiled and artifacts are generated
        const artifactsPath = `browser/artifacts/contracts/${contractName}.sol/${contractName}.json`; // Change this for different path
        const stakingArtifactsPath = `browser/artifacts/contracts/${stakingContractName}.sol/${stakingContractName}.json`; // Change this for different path
        const rewardDistributorAddress = "0x959715da68DC2D1329F4bb34e13Da03FE10c374b";

        let allLPPairs = [
            // "0xBc0Aa02e6363709D84388fC9aAbedE84f2Af1Eff",   // xTSLA/USX
            // "0xabBc34F80257B4fcb58ab6eafF9B3b70406c8C57",   // xAAPL/USX
            "0x2A41dd2c004AA2Ee42c527c1c2318F41845da2e9",   // xAMZN/USX
            "0x8Ee1932CA5618324E19545A0b8d3026B876e4188",   // xCOIN/USX
            "0x917ee7617aE1d03A836D2E4D5bb9EbE6C86ce125",   // BUSD/USX - kyber
            "0x5659929116fBa2F1A021228ec390CAfF7a2DE507",   // DF/USX - kyber
            "0x782F8a1375c88fD30c5c49b07a63dd97591F0ff3",   // EUX/USX - kyber
        ];

        let allNewRates = [
            // '23148148148148149', 
                        //    '23148148148148149', 
                           '23148148148148149', 
                           '23148148148148149', 
                           '34722222222222223', 
                           '81018518518518519', 
                           '17361111111111112']

        if (typeof remix == "object") {
            metadata = JSON.parse(
                await remix.call("fileManager", "getFile", artifactsPath)
            );
            stakingMetadata = JSON.parse(
                await remix.call("fileManager", "getFile", stakingArtifactsPath)
            );

            // 'web3Provider' is a remix global variable object
            signer = new ethers.providers.Web3Provider(web3Provider).getSigner();
        } else {
            console.log("you are forking");
            const owner = "0x4375c89af5b4af46791b05810c4b795a0470207f";

            await hre.network.provider.request({
                method: "hardhat_impersonateAccount",
                params: [owner],
            });

            signer = await ethers.provider.getSigner(owner);
            console.log("signer", signer._address);


            metadata = require("../artifacts/contracts/RewardDistributor.sol/RewardDistributor.json");
            stakingMetadata = require("../artifacts/contracts/StakingPool.sol/StakingPool.json");
        }

        const distributor = new ethers.Contract(rewardDistributorAddress, metadata.abi, signer);
        console.log("Proxy admin contract address: ", distributor.address);

        if (allLPPairs.length != allNewRates.length) {
            console.log("input parameters do not match");
            return;
        }

        //----------------------------------------------
        //------Upgrade reward rate for LP Pairs--------
        //----------------------------------------------
        for (let i = 0; i < allLPPairs.length; i++) {
            let stakingContract = new ethers.Contract(allLPPairs[i], stakingMetadata.abi, signer);
            console.log("staking contract is: ", stakingContract.address);
            let oldRate = await stakingContract.rewardRate();
            console.log("old rate is: ", oldRate.toString());

            // Set new rewards rate.
            tx = await distributor.setRecipientRewardRate(allLPPairs[i], allNewRates[i]);
            await tx.wait(1);

            let newRate = await stakingContract.rewardRate();
            console.log("new rate is: ", newRate.toString());
        }
        console.log("Finish!");
    } catch (e) {
        console.log(e.message);
    }
})();
