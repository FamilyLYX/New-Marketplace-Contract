// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import { ILSP8IdentifiableDigitalAsset } from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { LSP8MarketplaceOffer } from "./LSP8MarketplaceOffer.sol";
import { LSP8MarketplacePrice } from "./LSP8MarketplacePrice.sol";
import { LSP8MarketplaceTrade } from "./LSP8MarketplaceTrade.sol";
import { FamilyMarketPlaceEscrow } from "./MarketplaceEscrow.sol";
import { Verifier } from './MarketplaceVerifier.sol';
import {TransferHelper} from './libraries/transferHelpers.sol';


/**
 * @title LSP8Marketplace contract
 * @author Afteni Daniel (aka B00ste)
 *
* @notice For reference I will assume LSP8 is the same as NFT.
 */

contract LSP8Marketplace is LSP8MarketplaceOffer, LSP8MarketplacePrice, LSP8MarketplaceTrade, Verifier {

    using EnumerableSet for EnumerableSet.AddressSet;

    event ItemListed(address indexed collection, bytes32 tokenId, uint256 indexed price);

    event ItemDelisted(address collection, bytes32 tokenId);

    event TradeInitiated(bytes32 indexed tradeId, address indexed seller, address indexed buyer, address escrow, address collection, bytes32 tokenId);

    event Sent(bytes32 indexed tradeId, string indexed trackingId);

    event Dispute(bytes32 indexed tradeId, string indexed trackingId);

    event Received(bytes32 tradId);

    event Resolved(bytes32 tradId);

    event Dissolved(bytes32 tradId);

    uint256 private nonce = 0;

    address placeholder;
    address owner;
    EnumerableSet.AddressSet jurors;
    struct Trade{
        address seller;
        address buyer;
        address payable escrow;
    }
    mapping(bytes32 => Trade) trades;

    constructor(address _owner, address _placeholder){
        placeholder=_placeholder;
        owner=_owner;
    }


    modifier onlyJuror(){
        require(jurors.contains(msg.sender)|| msg.sender == owner, 'ACCESS DENIED');
        _;
    }


    function addJuror(address _juror) external {
        require(msg.sender==owner, 'ACCESS DENIED');
        jurors.add(_juror);
    }

    function removeJuror(address _juror) external {
        require(msg.sender==owner, 'ACCESS DENIED');
        jurors.remove(_juror);
    }





    // --- User Functionality.

    /**
     * Put an NFT on sale.
     * Allowed token standards: LSP8 (refference: "https://github.com/lukso-network/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset")
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that will be put on sale.
     * @param LYXAmount Buyout amount of LYX coins.
     * @param LSP7Addresses Addresses of the LSP7 token contracts allowed for buyout.
     * @param LSP7Amounts Buyout amounts in `LSP7Addresses` tokens.
     * 
     * @notice For information about `ownsLSP8` and `LSP8NotOnSale` modifiers and about `_addLSP8Sale` function check the LSP8MarketplaceSale smart contract.
     * For information about `_addLYXPrice` and `_addLSP7Prices` functions check the LSP8MArketplacePrice smart contract.
     */
    function putLSP8OnSale (
        address LSP8Address,
        bytes32 tokenId,
        uint256 LYXAmount,
        address[] memory LSP7Addresses,
        uint256[] memory LSP7Amounts,
        bool[3] memory allowedOffers,
        string memory uid, 
        bytes memory signature
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8NotOnSale(LSP8Address, tokenId)
    {
        verify(placeholder, uid, signature);
        _addLSP8Sale(LSP8Address, tokenId, allowedOffers);
        _addLYXPrice(LSP8Address, tokenId, LYXAmount);
        _addLSP7Prices(LSP8Address, tokenId, LSP7Addresses, LSP7Amounts);
        emit ItemListed(LSP8Address, tokenId, LYXAmount);
    }

    /**
     * Remove LSP8 sale. Also removes all the prices attached to the LSP8.
     * Allowed token standards: LSP8 (refference: "https://github.com/lukso-network/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset")
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that is on sale.
     *
     * @notice For information about `ownsLSP8` and `LSP8OnSale` modifiers and about `_removeLSP8Sale` check the LSP8MarketplaceSale smart contract.
     * For information about `_removeLSP8Prices` check the LSP8MArketplacePrice smart contract.
     * For information about `_removeLSP8Offers` check the LSP8MArketplaceOffers smart contract.
     */
    function removeLSP8FromSale (
        address LSP8Address,
        bytes32 tokenId
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
    {
        _removeOffers(LSP8Address, tokenId);
        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
    }

    /**
     * Change LYX price for a specific LSP8.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that is on sale.
     * @param LYXAmount buyout amount for the NFT on sale.
     *
     * @notice For information about `ownsLSP8` and `LSP8OnSale` modifiers check the LSP8MarketplaceSale smart contract.
     * For information about `_removeLYXPrice` and `_addLYXPrice` functions check the LSP8MarketplacePrice smart contract.
     */
    function changeLYXPrice (
        address LSP8Address,
        bytes32 tokenId,
        uint256 LYXAmount
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
    {
        _removeLYXPrice(LSP8Address, tokenId);
        _addLYXPrice(LSP8Address, tokenId, LYXAmount);
    }

    /**
     * Change LSP7 price for a specific LSP8.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that is on sale.
     * @param LSP7Address LSP7 address of an allowed token for buyout of the NFT.
     * @param LSP7Amount New buyout amount in `LSP7Address` token for the NFT on sale.
     *
     * @notice For information about `ownsLSP8` and `LSP8OnSale` modifiers check the LSP8MarketplaceSale smart contract.
     * For information about `LSP7PriceDoesNotExist` modifier check LSP8MarketplacePrice smart contract.
     * For information about `removeLSP7PriceByAddress` and `_addLSP7PriceByAddress` methods check the LSP8MarketplacePrice smart contract.
     */
    function changeLSP7Price (
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address,
        uint256 LSP7Amount
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
        LSP7PriceDoesNotExist(LSP8Address, tokenId, LSP7Address)
    {
        _removeLSP7PriceByAddress(LSP8Address, tokenId, LSP7Address);
        _addLSP7PriceByAddress(LSP8Address, tokenId, LSP7Address, LSP7Amount);
    }

    /**
     * Add LSP7 price for a specific LSP8.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that is on sale.
     * @param LSP7Address LSP7 address of an allowed token for buyout of the NFT.
     * @param LSP7Amount New buyout amount in `LSP7Address` token for the NFT on sale.
     *
     * @notice For information about `ownsLSP8` and `LSP8OnSale` modifiers
     * check the LSP8MarketplaceSale smart contract.
     * For information about `LSP7PriceDoesExist` modifier and `_addLSP7PriceByAddress` method
     * check the LSP8MarketplacePrice smart contract.
     */
    function addLSP7Price (
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address,
        uint256 LSP7Amount
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
        LSP7PriceDoesExist(LSP8Address, tokenId, LSP7Address)
    {
        _addLSP7PriceByAddress(LSP8Address, tokenId, LSP7Address, LSP7Amount);
    }

    /**
     * Buy LSP8 with LYX.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that is on sale.
     *
     * @notice For information about `LSP8OnSale` modifier and `_removeLSP8Sale` method
     * check the LSP8MarketplaceSale smart contract.
     * For information about `sendEnoughLYX` modifier and `_removeLSP8Prices`, `_returnLYXPrice` methods
     * check the LSP8MarketplacePrice smart contract.
     * For information about `_removeLSP8Offers` method check the LSP8MarketplaceOffer smart contract.
     * For information about `_transferLSP8` method check the LSP8MarketplaceTrade smart contract. 
     */
    function buyLSP8WithLYX (
        address LSP8Address,
        bytes32 tokenId
    )
        external
        payable
        sendEnoughLYX(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
    {
        address payable LSP8Owner = payable(ILSP8IdentifiableDigitalAsset(LSP8Address).tokenOwnerOf(tokenId));
        uint amount = _returnLYXPrice(LSP8Address, tokenId);
        bytes32 tradeId = keccak256(abi.encodePacked(LSP8Owner, msg.sender, amount, LSP8Address, tokenId, nonce));
        address escrow = address(new FamilyMarketPlaceEscrow(LSP8Address, tokenId, LSP8Owner, msg.sender, amount ));
        
        _removeOffers(LSP8Address, tokenId);
        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP8(LSP8Address, LSP8Owner, escrow, tokenId, false, 1);
        TransferHelper.safeTransferLYX(LSP8Owner, amount);
        // LSP8Owner.transfer(amount);
        trades[tradeId] = Trade(LSP8Owner, msg.sender, payable(escrow) );
        nonce++;
        emit TradeInitiated(tradeId, LSP8Owner, msg.sender, escrow, LSP8Address, tokenId);
    }

    /**
     * Buy LSP8 with LSP7.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` LSP8 that is on sale.
     * @param LSP7Address Address of the token which is allowed for buyout.
     *
     * @notice For information about `LSP8OnSale` modifier check the LSP8MarketplaceSale smart contract.
     * For information about `haveEnoughLSP7Balance` and `sellerAcceptsToken` modifiers
     * and `_removeLSP8Prices` method check the LSP8MarketplacePrice smart contract.
     * For information about `_removeLSP8Offers` method check the LSP8MarketplaceOffer smart contract.
     * For information about `_transferLSP8` and `_transferLSP7` methods
     * check the LSP8MarketplaceTrade smart contract. 
     */
    function buyLSP8WithLSP7 (
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address
    )
        external
        haveEnoughLSP7Balance(LSP8Address, tokenId, LSP7Address)
        sellerAcceptsToken(LSP8Address, tokenId, LSP7Address)
        LSP8OnSale(LSP8Address, tokenId)
    {
        address LSP8Owner = ILSP8IdentifiableDigitalAsset(LSP8Address).tokenOwnerOf(tokenId);
        uint256 amount = _returnLSP7PriceByAddress(LSP8Address, tokenId, LSP7Address);
 
        _removeOffers(LSP8Address, tokenId);
        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP7(LSP7Address, msg.sender, LSP8Owner, amount, false);
        _transferLSP8(LSP8Address, LSP8Owner, msg.sender, tokenId, false, 1);
    }

    /**
     * Offer LSP8 in exchange for an LSP8 that is on sale.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` LSP8 that is on sale.
     * @param offerLSP8Address Address of the LSP8 offered in exchange.
     * @param offerTokenId Token id of the `offerLSP8Address` LSP8 that is offered.
     *
     * @notice For information about `LSP8OnSale` and `ownsLSP8` modifier
     * check the LSP8MarketplaceSale smart contract.
     * For information about `offerDoesNotExist` modifier and `_makeLSP8Offer` method
     * check the LSP8MarketplaceOffer smart contract.
     */
    function offerLSP8ForLSP8 (
        address LSP8Address,
        bytes32 tokenId,
        address offerLSP8Address,
        bytes32 offerTokenId
    )
        external
        LSP8OnSale(LSP8Address, tokenId)
        ownsLSP8(offerLSP8Address, offerTokenId)
        LSP8OfferDoesNotExist(offerLSP8Address, offerTokenId)
        allowsLSP8Offers(LSP8Address, tokenId)
    {
        _makeLSP8Offer(LSP8Address, tokenId, offerLSP8Address, offerTokenId);
    }

    /**
     * Remove LSP8 from the offers of a certain LSP8.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` LSP8 that is on sale.
     * @param offerLSP8Address Address of the LSP8 that is to be removed from offers.
     * @param offerTokenId Token id of the `offerLSP8Address` LSP8 that is to be removed.
     *
     * @notice For information about `LSP8OnSale` and `ownsLSP8` modifier
     * check the LSP8MarketplaceSale smart contract.
     * For information about `offerExists` modifier and `_removeLSP8Offer` method
     * check the LSP8MarketplaceOffer smart contract.
     */
    function removeLSP8OfferForLSP8 (
        address LSP8Address,
        bytes32 tokenId,
        address offerLSP8Address,
        bytes32 offerTokenId
    )
        external
        LSP8OnSale(LSP8Address, tokenId)
        ownsLSP8(offerLSP8Address, offerTokenId)
        LSP8OfferExists(offerLSP8Address, offerTokenId)
    {
        _removeLSP8Offer(LSP8Address, tokenId, offerLSP8Address, offerTokenId);
    }

    /**
     * Accept LSP8 offer for trade.
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` LSP8 that is on sale.
     * @param offerLSP8Address Address of the LSP8 that is to be accepted.
     * @param offerTokenId Token id of the `offerLSP8Address` LSP8 that is to be accepted.
     *
     * @notice For information about `LSP8OnSale`, `ownsLSP8` modifier
     * and `_removeLSP8Sale` method check the LSP8MarketplaceSale smart contract.
     * For information about `offerExistsForThisLSP8` modifier and `_removeLSP8Offers` method
     * check the LSP8MarketplaceOffer smart contract.
     * For information about `_removeLSP8Prices` method check
     * the LSP8MarketplacePrice smrt contract.
     * For information about `_transferLSP8` method check
     * the LSP8MarketplaceTrade smart contract.
     */
    function acceptLSP8OfferForLSP8 (
        address LSP8Address,
        bytes32 tokenId,
        address offerLSP8Address,
        bytes32 offerTokenId
    )
        external
        LSP8OnSale(LSP8Address, tokenId)
        ownsLSP8(LSP8Address, tokenId)
        LSP8OfferExistsForThisLSP8(LSP8Address, tokenId, offerLSP8Address, offerTokenId)
    {
        address offerLSP8Owner = ILSP8IdentifiableDigitalAsset(offerLSP8Address).tokenOwnerOf(offerTokenId);

        _removeOffers(LSP8Address, tokenId);
        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP8(LSP8Address, msg.sender, offerLSP8Owner, tokenId, false, 1);
        _transferLSP8(offerLSP8Address, offerLSP8Owner, msg.sender, offerTokenId, false, 1);
    }

    /**
     * Create LSP7 offer.
     *
     * @param LSP8Address LSP8 address.
     * @param tokenId LSP8 token id.
     * @param LSP7Address Address of the LSP7 token offered.
     * @param LSP7Amount Amount of LSP7 tokens offered.
     *
     * @notice For information about `LSP8OnSale` and `allowsLSP7Offers`
     * please check the LSP8MarketplaceSale smart contract.
     * For information about `haveEnoughLSP7BalanceForOffer` modifier and
     * `_makeLSP7Offer` method please check the LSP8MarketplaceOffer smart contract.
     */
    function makeLSP7Offer (
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address,
        uint256 LSP7Amount
    )
        external
        LSP8OnSale(LSP8Address, tokenId)
        allowsLSP7Offers(LSP8Address, tokenId)
        haveEnoughLSP7BalanceForOffer(LSP7Address, LSP7Amount)
    {
        _makeLSP7Offer(LSP8Address, tokenId, LSP7Address, LSP7Amount);
    }

    /**
     * Remove LSP7 offer.
     *
     * @param LSP8Address LSP8 address.
     * @param tokenId LSP8 token id.
     * @param LSP7Address Address of the LSP7 token offered.
     *
     * @notice For information about `LSP8OnSale` and `allowsLSP7Offers`
     * modifiers please check the LSP8MarketplaceSale smart contract.
     * For information about `LSP7OfferExistsAndOwned` modifier and
     * `_removeLSP7Offer` method please check the LSP8MarketplaceOffer smart contract.
     */
    function removeLSP7Offer (
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address
    )
        external
        LSP8OnSale(LSP8Address, tokenId)
        allowsLSP7Offers(LSP8Address, tokenId)
        LSP7OfferExists(LSP8Address, tokenId, LSP7Address, msg.sender)
    {
        _removeLSP7Offer(LSP8Address, tokenId, LSP7Address);
    }

    /**
     * Confirm physical item has been sent.
     *
     * 
     */
    function confirmSent(bytes32 tradeId, string memory trackingId)external{
        Trade memory trade=trades[tradeId];
        require(trade.seller==msg.sender,'');
        FamilyMarketPlaceEscrow(trade.escrow).markSent(trackingId);
        emit Sent(tradeId, trackingId);
    }

    /**
     * Confirm physical item has been received.
     *
     * 
     */
    function confirmReceived(bytes32 tradeId,  string memory uid, bytes memory signature)external{
        Trade memory trade=trades[tradeId];
        require(trade.buyer==msg.sender,'');
        verify(placeholder, uid, signature);
        FamilyMarketPlaceEscrow(trade.escrow).release();
        emit Received(tradeId);
    }

    /**
     * Open Dispute.
     *
     * 
     */
    function openDispute(bytes32 tradeId, string memory reason )external{
        Trade memory trade=trades[tradeId];
        require(trade.seller==msg.sender || trade.buyer==msg.sender,'');
        FamilyMarketPlaceEscrow(trade.escrow).dispute();
        emit Dispute(tradeId, reason);
    }

    /**
     * Dissolve trade by juror.
     *
     * 
     */
    function dissolveTrade(bytes32 tradeId)external{
        require(jurors.contains(msg.sender),'');
        Trade memory trade=trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).dissolve();
        emit Dissolved(tradeId);
    }

    /**
     * Resolve trade.
     *
     * 
     */
    function resolveTrade(bytes32 tradeId) external{
        require(jurors.contains(msg.sender),'');
        Trade memory trade=trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).settle();
        emit Resolved(tradeId);
    }



    /**
     * Accept LSP7 offer.
     *
     * @param LSP8Address LSP8 address.
     * @param tokenId LSP8 token id.
     * @param LSP7Address LSP7 address.
     * @param offerCreator The owner of the accepted offer.
     *
     * @notice a
     */
    function acceptLSP7Offer (
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address,
        address offerCreator
    )
        external
        LSP8OnSale(LSP8Address, tokenId)
        allowsLSP7Offers(LSP8Address, tokenId)
        LSP7OfferExists(LSP8Address, tokenId, LSP7Address, offerCreator)
        offerCreatorHasEnoughLSP7Balance(LSP8Address, tokenId, LSP7Address, offerCreator)
    {
        _removeOffers(LSP8Address, tokenId);
        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP8(LSP8Address, msg.sender, offerCreator, tokenId, false, 1);
        _transferLSP7(
            LSP7Address,
            offerCreator,
            msg.sender,
            _returnLSP7OfferAmount(LSP8Address, tokenId, LSP7Address, offerCreator),
            false
        );
    }
    
}
