// import { ethers } from "hardhat";
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { FamilyNft, LSP8Marketplace } from '../typechain-types';
import { toBeHex, zeroPadBytes } from 'ethers';
import ERC725 from '@erc725/erc725.js';
// import { PromiseOrValue } from '../typechain-types/common';
// import { Signer } from 'ethers';
const schemas = [
  {
    name: 'LSP18RoyaltiesRecipients',
    key: '0xc0569ca6c9180acc2c3590f36330a36ae19015a19f4e85c28a7631e3317e6b9d',
    keyType: 'Singleton',
    valueType: '(bytes4,address,uint32)[CompactBytesArray]',
    valueContent: '(Bytes4,Address,Number)',
  },
];

function encodeCompactBytesArray(values: any[]) {
  return ethers.solidityPacked(['bytes4', 'address', 'uint32'], values);
}

// Define a describe block for your test suite
describe('LSP8Marketplace', function () {
  // Declare variables for contract instance and signers
  let LSP8Marketplace;
  let lsp8Marketplace: LSP8Marketplace;
  let owner: any;
  let user: any;
  let LSP8;
  let lsp8: FamilyNft;
  let lsp8Address: string;

  // Define before hook to deploy the contract and get signers
  before(async function () {
    // Get signers from ethers
    [owner, user] = await ethers.getSigners();
    const tokenId = toBeHex(1);

    LSP8 = await ethers.getContractFactory('FamilyNft');
    lsp8 = await LSP8.deploy();
    await lsp8.waitForDeployment();
    lsp8Address = await lsp8.getAddress();
    console.log('deployed nft', lsp8Address, zeroPadBytes(tokenId, 32));
    let minting = await lsp8.mint(owner.address, '', zeroPadBytes(tokenId, 32));
    const data = ERC725.encodeData(
      [
        {
          value: [
            '0x12345678', // bytes4
            '0x5FbDB2315678afecb367f032d93F642f64180aa3', // address
            '15000', // uint32
          ],
          keyName: 'LSP18RoyaltiesRecipients',
        },
      ],
      schemas
    );
    console.log('royalty', data.values[0]);
    let settingRoyalty = await lsp8.setData(
      '0xc0569ca6c9180acc2c3590f36330a36ae19015a19f4e85c28a7631e3317e6b9d',
      data.values[0]
    );
    console.log('deployed and minted nft and set royalty');

    // Deploy the contract
    LSP8Marketplace = await ethers.getContractFactory('LSP8Marketplace');
    lsp8Marketplace = await LSP8Marketplace.deploy(
      owner.address,
      owner.address,
      owner.address
    );
    await lsp8Marketplace.waitForDeployment();
  });

  // Define a test case for putDigitalLSP8OnSale function
  it('should put Digital LSP8 on sale', async function () {
    const price = ethers.parseEther('1');
    console.log('deployed, about to run test');
    const tokenId = toBeHex(1);

    // Call the putDigitalLSP8OnSale function
    await lsp8Marketplace
      .connect(owner)
      .putDigitalLSP8OnSale(
        lsp8Address,
        zeroPadBytes(tokenId, 32),
        price,
        'link',
        true
      );

    // co

    // Get the sale details

    // Check if the sale details are as expected
    // expect(sale).to.equal([false, false, false]);
    // expect(sale.price).to.equal(price);
  });

  it('should put Digital LSP8 on sale', async function () {
    const price = ethers.parseEther('1');
    console.log('deployed, about to run test');
    const tokenId = toBeHex(1);

    // Call the putDigitalLSP8OnSale function
    await lsp8Marketplace
      .connect(owner)
      .putDigitalLSP8OnSale(
        lsp8Address,
        zeroPadBytes(tokenId, 32),
        price,
        'link',
        true
      );

    // co

    // Get the sale details

    // Check if the sale details are as expected
    // expect(sale).to.equal([false, false, false]);
    // expect(sale.price).to.equal(price);
  });

  it('should intiate trade', async function () {
    const price = ethers.parseEther('1');
    console.log('deployed, about to run test');
    const tokenId = toBeHex(1);

    // Call the putDigitalLSP8OnSale function
    const trade = await lsp8Marketplace
      .connect(user)
      .buyDigitalLSP8WithLYX(lsp8Address, zeroPadBytes(tokenId, 32));

    const receipt = await trade.wait();
    console.log(receipt?.logs);

    // co

    // Get the sale details

    // Check if the sale details are as expected
    // expect(sale).to.equal([false, false, false]);
    // expect(sale.price).to.equal(price);
  });

  //   it('should confirm the trade and address should recieve fee', async function () {
  //     const price = ethers.parseEther('1');
  //     console.log('deployed, about to run test');
  //     const tokenId = toBeHex(1);

  //     // Call the putDigitalLSP8OnSale function
  //     await lsp8Marketplace
  //       .connect(user)
  //       .confirmDigitalReceived(lsp8Address, zeroPadBytes(tokenId, 32));

  //     // co

  //     // Get the sale details

  //     // Check if the sale details are as expected
  //     // expect(sale).to.equal([false, false, false]);
  //     // expect(sale.price).to.equal(price);
  //   });
});
