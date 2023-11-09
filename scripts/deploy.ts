// import { ethers } from "hardhat";
import { ethers } from "hardhat";

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;

  const lockedAmount = ethers.utils.parseEther("1");

  const LSP8Marketplace = await ethers.getContractFactory("LSP8Marketplace");
  const _LSP8Marketplace = await LSP8Marketplace.deploy(
    "0x2b55C256018B6CF2D6856A4780D88f5eEE8583B5",
    "0x2b55C256018B6CF2D6856A4780D88f5eEE8583B5"
  );

  await _LSP8Marketplace.deployed();

  console.log(`LSP8Marketplace deployed to ${_LSP8Marketplace.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
