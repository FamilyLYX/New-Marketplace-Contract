// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import {ILSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {LSP8MarketplacePrice} from "./LSP8MarketplacePrice.sol";
import {LSP8MarketplaceTrade} from "./LSP8MarketplaceTrade.sol";
import {FamilyMarketPlaceEscrow} from "./MarketplaceEscrow.sol";
import {Verifier} from "./MarketplaceVerifier.sol";
import {TransferHelper} from "./libraries/transferHelpers.sol";

error LSP8Marketplace__OnlyAdmin();

/**
 * @title LSP8Marketplace contract
 * @author Afteni Daniel (aka B00ste)
 *
 * @notice For reference I will assume LSP8 is the same as NFT.
 */

contract LSP8Marketplace is
    LSP8MarketplacePrice,
    LSP8MarketplaceTrade,
    Verifier
{
    using EnumerableSet for EnumerableSet.AddressSet;

    enum CollectionType {
        Digital,
        Phygital
    }

    /**
     *
     * @notice when new admin is set
     * @param oldAdmin address of previous admin
     * @param newAdmin address of new admin
     */
    event SetAdmin(address oldAdmin, address newAdmin);

    event ItemListed(
        address indexed collection,
        bytes32 indexed tokenId,
        uint256 indexed price,
        string listingURl,
        bool ItemListed,
        CollectionType collectionType
    );

    event ItemDelisted(address collection, bytes32 tokenId);

    event TradeInitiated(
        bytes32 indexed tradeId,
        address indexed seller,
        address indexed buyer,
        address escrow,
        address collection,
        bytes32 tokenId,
        uint256 price
    );

    event Sent(bytes32 indexed tradeId, string indexed trackingId);

    event Dispute(bytes32 indexed tradeId, string indexed trackingId);

    event Received(bytes32 tradeId);

    event Resolved(bytes32 tradeId);

    event Dissolved(bytes32 tradeId);

    event ReceivedFiat(bytes32 tradeId);

    event ResolvedFiat(bytes32 tradeId);

    event DissolvedFiat(bytes32 tradeId);

    uint256 private nonce = 0;

    address placeholder;
    address owner;
    address public admin;

    struct Trade {
        address seller;
        address buyer;
        address payable escrow;
    }

    mapping(bytes32 => Trade) trades;

    mapping(address escrow => bool) public isEscrow;

    constructor(address _owner, address _admin, address _placeholder) {
        placeholder = _placeholder;
        owner = _owner;
        admin = _admin;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert LSP8Marketplace__OnlyAdmin();
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ACCESS DENIED");
        _;
    }

    /**
     * @notice sets a new admin
     * @dev can only be called by current admin
     * @param _newAdmin address of new admin
     */
    function setAdmin(address _newAdmin) external onlyAdmin {
        address oldAdmin = admin;

        admin = _newAdmin;

        emit SetAdmin(oldAdmin, _newAdmin);
    }

    // --- User Functionality.

    /**
     * Put an NFT on sale.
     * Allowed token standards: LSP8 (refference: "https://github.com/lukso-network/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset")
     *
     * @param LSP8Address Address of the LSP8 token contract.
     * @param tokenId Token id of the `LSP8Address` NFT that will be put on sale.
     * @param LYXAmount Buyout amount of LYX coins.
     *
     * @notice For information about `ownsLSP8` and `LSP8NotOnSale` modifiers and about `_addLSP8Sale` function check the LSP8MarketplaceSale smart contract.
     * For information about `_addLYXPrice` and `_addLSP7Prices` functions check the LSP8MArketplacePrice smart contract.
     */
    function putLSP8OnSale(
        address LSP8Address,
        bytes32 tokenId,
        uint256 LYXAmount,
        string memory uid,
        bytes memory signature,
        string memory listingURl,
        bool _acceptFiat
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8NotOnSale(LSP8Address, tokenId)
    {
        verify(placeholder, uid, signature);
        _addLSP8Sale(LSP8Address, tokenId, _acceptFiat);
        _addLYXPrice(LSP8Address, tokenId, LYXAmount);
        emit ItemListed(
            LSP8Address,
            tokenId,
            LYXAmount,
            listingURl,
            _acceptFiat,
            CollectionType.Phygital
        );
    }

    function putDigitalLSP8OnSale(
        address LSP8Address,
        bytes32 tokenId,
        uint256 LYXAmount,
        string memory listingURl,
        bool _acceptFiat
    )
        external
        ownsLSP8(LSP8Address, tokenId)
        LSP8NotOnSale(LSP8Address, tokenId)
    {
        _addLSP8Sale(LSP8Address, tokenId, _acceptFiat);
        _addLYXPrice(LSP8Address, tokenId, LYXAmount);
        emit ItemListed(
            LSP8Address,
            tokenId,
            LYXAmount,
            listingURl,
            _acceptFiat,
            CollectionType.Digital
        );
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
    function removeLSP8FromSale(
        address LSP8Address,
        bytes32 tokenId
    ) external ownsLSP8(LSP8Address, tokenId) LSP8OnSale(LSP8Address, tokenId) {
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
    function changeLYXPrice(
        address LSP8Address,
        bytes32 tokenId,
        uint256 LYXAmount
    ) external ownsLSP8(LSP8Address, tokenId) LSP8OnSale(LSP8Address, tokenId) {
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
    function changeLSP7Price(
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
    function addLSP7Price(
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
    function buyLSP8WithLYX(
        address LSP8Address,
        bytes32 tokenId
    )
        external
        payable
        sendEnoughLYX(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
    {
        address payable LSP8Owner = payable(
            ILSP8IdentifiableDigitalAsset(LSP8Address).tokenOwnerOf(tokenId)
        );
        uint amount = _returnLYXPrice(LSP8Address, tokenId);
        bytes32 tradeId = keccak256(
            abi.encodePacked(
                LSP8Owner,
                msg.sender,
                amount,
                LSP8Address,
                tokenId,
                nonce
            )
        );
        address escrow = address(
            new FamilyMarketPlaceEscrow(
                LSP8Address,
                tokenId,
                LSP8Owner,
                msg.sender,
                amount,
                admin
            )
        );

        isEscrow[escrow] = true;

        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP8(LSP8Address, LSP8Owner, escrow, tokenId, false, 1);
        TransferHelper.safeTransferLYX(escrow, amount);
        // LSP8Owner.transfer(amount);
        trades[tradeId] = Trade(LSP8Owner, msg.sender, payable(escrow));
        nonce++;
        emit TradeInitiated(
            tradeId,
            LSP8Owner,
            msg.sender,
            escrow,
            LSP8Address,
            tokenId,
            amount
        );
    }

    function buyLSP8WithFiat(
        address LSP8Address,
        address buyer,
        bytes32 tokenId
    )
        external
        payable
        sendEnoughLYX(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
        allowFiat(LSP8Address, tokenId)
    {
        require(msg.sender == owner, "ACCESS DENIED");
        address collection = LSP8Address;
        bytes32 _tokenId = tokenId;

        address payable LSP8Owner = payable(
            ILSP8IdentifiableDigitalAsset(collection).tokenOwnerOf(tokenId)
        );
        uint amount = _returnLYXPrice(collection, tokenId);
        address _buyer = buyer;
        bytes32 tradeId = keccak256(
            abi.encodePacked(
                LSP8Owner,
                _buyer,
                amount,
                collection,
                _tokenId,
                nonce
            )
        );
        address escrow = address(
            new FamilyMarketPlaceEscrow(
                collection,
                _tokenId,
                LSP8Owner,
                _buyer,
                amount,
                admin
            )
        );

        isEscrow[escrow] = true;

        _removeLSP8Prices(collection, tokenId);
        _transferLSP8(collection, LSP8Owner, escrow, _tokenId, false, 1);
        // LSP8Owner.transfer(amount);
        trades[tradeId] = Trade(LSP8Owner, _buyer, payable(escrow));
        nonce++;
        emit TradeInitiated(
            tradeId,
            LSP8Owner,
            _buyer,
            escrow,
            collection,
            _tokenId,
            amount
        );
    }

    function buyDigitalLSP8WithLYX(
        address LSP8Address,
        bytes32 tokenId
    )
        external
        payable
        sendEnoughLYX(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
    {
        address payable LSP8Owner = payable(
            ILSP8IdentifiableDigitalAsset(LSP8Address).tokenOwnerOf(tokenId)
        );
        uint amount = _returnLYXPrice(LSP8Address, tokenId);
        bytes32 tradeId = keccak256(
            abi.encodePacked(
                LSP8Owner,
                msg.sender,
                amount,
                LSP8Address,
                tokenId,
                nonce
            )
        );

        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP8(LSP8Address, LSP8Owner, msg.sender, tokenId, false, 1);
        TransferHelper.safeTransferLYX(LSP8Owner, amount);
        // LSP8Owner.transfer(amount);
        trades[tradeId] = Trade(LSP8Owner, msg.sender, payable(address(0)));
        nonce++;
        emit TradeInitiated(
            tradeId,
            LSP8Owner,
            msg.sender,
            address(0),
            LSP8Address,
            tokenId,
            amount
        );
    }

    function buyDigitalLSP8WithFiat(
        address LSP8Address,
        bytes32 tokenId,
        address buyer
    )
        external
        payable
        sendEnoughLYX(LSP8Address, tokenId)
        LSP8OnSale(LSP8Address, tokenId)
    {
        address payable LSP8Owner = payable(
            ILSP8IdentifiableDigitalAsset(LSP8Address).tokenOwnerOf(tokenId)
        );
        uint amount = _returnLYXPrice(LSP8Address, tokenId);
        bytes32 tradeId = keccak256(
            abi.encodePacked(
                LSP8Owner,
                buyer,
                amount,
                LSP8Address,
                tokenId,
                nonce
            )
        );

        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP8(LSP8Address, LSP8Owner, buyer, tokenId, false, 1);
        trades[tradeId] = Trade(LSP8Owner, buyer, payable(address(0)));
        nonce++;
        emit TradeInitiated(
            tradeId,
            LSP8Owner,
            buyer,
            address(0),
            LSP8Address,
            tokenId,
            amount
        );
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
    function buyLSP8WithLSP7(
        address LSP8Address,
        bytes32 tokenId,
        address LSP7Address
    )
        external
        haveEnoughLSP7Balance(LSP8Address, tokenId, LSP7Address)
        sellerAcceptsToken(LSP8Address, tokenId, LSP7Address)
        LSP8OnSale(LSP8Address, tokenId)
    {
        address LSP8Owner = ILSP8IdentifiableDigitalAsset(LSP8Address)
            .tokenOwnerOf(tokenId);
        uint256 amount = _returnLSP7PriceByAddress(
            LSP8Address,
            tokenId,
            LSP7Address
        );

        _removeLSP8Prices(LSP8Address, tokenId);
        _removeLSP8Sale(LSP8Address, tokenId);
        _transferLSP7(LSP7Address, msg.sender, LSP8Owner, amount, false);
        _transferLSP8(LSP8Address, LSP8Owner, msg.sender, tokenId, false, 1);
    }

    /**
     * Confirm physical item has been sent.
     *
     *
     */
    function confirmSent(bytes32 tradeId, string memory trackingId) external {
        Trade memory trade = trades[tradeId];
        require(trade.seller == msg.sender, "");
        FamilyMarketPlaceEscrow(trade.escrow).markSent(trackingId);
        emit Sent(tradeId, trackingId);
    }

    /**
     * Confirm physical item has been received.
     *
     *
     */
    function confirmReceived(
        bytes32 tradeId,
        string memory uid,
        bytes memory signature
    ) external {
        Trade memory trade = trades[tradeId];
        require(trade.buyer == msg.sender, "");
        verify(placeholder, uid, signature);
        FamilyMarketPlaceEscrow(trade.escrow).release();
        emit Received(tradeId);
    }

    function confirmDigitalReceived(bytes32 tradeId) external {
        Trade memory trade = trades[tradeId];
        require(trade.buyer == msg.sender, "");
        FamilyMarketPlaceEscrow(trade.escrow).release();
        emit Received(tradeId);
    }

    function confirmReceivedFiat(
        bytes32 tradeId,
        string memory uid,
        bytes memory signature
    ) external onlyOwner {
        Trade memory trade = trades[tradeId];
        verify(placeholder, uid, signature);
        FamilyMarketPlaceEscrow(trade.escrow).releaseFiat();
        emit Received(tradeId);
        emit ReceivedFiat(tradeId);
    }

    function confirmDigitalReceivedFiat(bytes32 tradeId) external onlyOwner {
        Trade memory trade = trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).releaseFiat();
        emit Received(tradeId);
        emit ReceivedFiat(tradeId);
    }

    /**
     * Open Dispute.
     *
     *
     */
    function openDispute(bytes32 tradeId, string memory reason) external {
        Trade memory trade = trades[tradeId];
        require(trade.seller == msg.sender || trade.buyer == msg.sender, "");
        FamilyMarketPlaceEscrow(trade.escrow).dispute();
        emit Dispute(tradeId, reason);
    }

    /**
     * Dissolve trade by admin.
     *
     *
     */
    function dissolveTrade(bytes32 tradeId) external onlyAdmin {
        Trade memory trade = trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).dissolve();
        emit Dissolved(tradeId);
    }

    function dissolveTradeFiat(bytes32 tradeId) external onlyAdmin {
        Trade memory trade = trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).dissolve();
        emit Dissolved(tradeId);
        emit DissolvedFiat(tradeId);
    }

    /**
     * Resolve trade.
     *
     *
     */
    function resolveTrade(bytes32 tradeId) external onlyAdmin {
        Trade memory trade = trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).settle();
        emit Resolved(tradeId);
    }

    function resolveTradeFiat(bytes32 tradeId) external onlyAdmin {
        Trade memory trade = trades[tradeId];
        FamilyMarketPlaceEscrow(trade.escrow).settleFiat();
        emit Resolved(tradeId);
        emit ResolvedFiat(tradeId);
    }
}
