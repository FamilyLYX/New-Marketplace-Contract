// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/LSP8IdentifiableDigitalAsset.sol";

contract FamilyNft is LSP8IdentifiableDigitalAsset {
    constructor()
        LSP8IdentifiableDigitalAsset("FAMILYNFT", "FNFT", msg.sender, 2, 2)
    {}

    function mint(address to, string memory data, bytes32 tokenId) public {
        _mint(to, tokenId, true, "0x");
    }
}
