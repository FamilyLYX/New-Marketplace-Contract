// import { ethers } from "hardhat";
import { ethers } from "hardhat";
import { expect } from "chai";
import { FamilyNft, LSP8Marketplace } from "../typechain-types";
import { PromiseOrValue } from "../typechain-types/common";
import { Signer } from "ethers";
import { hexZeroPad, hexlify } from "ethers/lib/utils";

// Define a describe block for your test suite
describe("LSP8Marketplace", function () {
  // Declare variables for contract instance and signers
  let LSP8Marketplace;
  let lsp8Marketplace: LSP8Marketplace;
  let owner: any;
  let user;
  let LSP8;
  let lsp8: FamilyNft;

  // Define before hook to deploy the contract and get signers
  before(async function () {
    // Get signers from ethers
    [owner, user] = await ethers.getSigners();
    const tokenId = ethers.utils.hexValue(1);

    LSP8 = await ethers.getContractFactory("FamilyNft");
    lsp8 = await LSP8.deploy();
    await lsp8.deployed();
    console.log("deployed nft", lsp8.address, hexZeroPad(tokenId, 32));
    let minting = await lsp8.mint(owner.address, "", hexZeroPad(tokenId, 32));
    console.log("deployed and minted nft");

    // Deploy the contract
    LSP8Marketplace = await ethers.getContractFactory("LSP8Marketplace");
    lsp8Marketplace = await LSP8Marketplace.deploy(
      owner.address,
      owner.address
    );
    await lsp8Marketplace.deployed();
  });

  // Define a test case for putDigitalLSP8OnSale function
  it("should put Digital LSP8 on sale", async function () {
    const price = ethers.utils.parseEther("1");
    console.log("deployed, about to run test");
    const tokenId = ethers.utils.hexValue(1);

    // Call the putDigitalLSP8OnSale function
    await lsp8Marketplace
      .connect(owner)
      .putDigitalLSP8OnSale(
        lsp8.address,
        hexZeroPad(tokenId, 32),
        price,
        "link",
        true
      );

    // co

    // Get the sale details

    // Check if the sale details are as expected
    // expect(sale).to.equal([false, false, false]);
    // expect(sale.price).to.equal(price);
  });
});
