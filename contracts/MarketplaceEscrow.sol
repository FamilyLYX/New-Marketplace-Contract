// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {TransferHelper} from './libraries/transferHelpers.sol';

/**
 * @title Family Escrow Contract
 *
 */


contract FamilyMarketPlaceEscrow is ReentrancyGuard{

    address owner;
    address LSP8Collection;
    bytes32 tokenId;
    address seller;
    address buyer;
    uint256 balance;
    // address OGminter;
    uint256 timestamp;
    uint256 escrowId;
    status escrowStatus;
    string trackingID;

    enum status {
        OPEN, // 0, trade is ongoing
        SENT, // 1, item as been sent
        CONFIRMED, // 2, trade can be confirmed
        CANCELED, // 3, trade has been canceled
        DISPUTED, // 4, trade is in dispute - set period before assets are withheld
        DISSOLVED // 5, trade has been closed
    }

    fallback() external payable {
        // emit Transfer("fallback", msg.sender, msg.value, msg.data);
    }

    receive() external payable {
        // emit Transfer("receive", msg.sender, msg.value, bytes(""));
    }

    // event Transfer(string func, address sender, uint256 value, bytes data); // what data?
    event Action(string func, address sender, bytes data); // what data?

    // modifier itemExists(uint256 escId) {
    //     require(items[escId].timestamp != 0, "Escrow item does not exist.");
    //     _;
    // }

    modifier itemIsOpen() {
        require(escrowStatus == status.OPEN, "Escrow item has been closed.");
        _;
    }

    modifier onlyMarketplace() {
        require(msg.sender == owner, "Sender Not Marketplace");
        _;
    }

    /**
     * Called by marketplace when buyer commits to make payment.
     * Locks LSP8 LYX in escrow until exchange is complete.
     *
     * @param LSP8Address Address of the LSP8 to be transfered.
     * @param _tokenId Token escrowId of the LSP8 to be transferred.
     * @param _seller Address of the LSP8 sender (aka from).
     * @param _buyer Address of the LSP8 receiver (aka to).
     * @param amount Sale price of asset.
     *
     * @notice this method can only be called once Buyer commits LYX payment
     */

    constructor(
        address LSP8Address,
        bytes32 _tokenId,
        address _seller,
        address _buyer,
        uint256 amount
    ) {
        LSP8Collection = LSP8Address;
        tokenId = _tokenId;
        seller = _seller;
        buyer = _buyer;
        timestamp = block.timestamp;
        escrowStatus = status.OPEN;
        balance = amount;
        owner=msg.sender;
    }



    function getBuyerSeller() public view returns (address[2] memory) {
        return [buyer, seller];
    }

    function getBalance() public view returns (uint256) {
        return balance;
    }

    function _setEscrowStatus(status newStatus) internal {
        escrowStatus = newStatus;
    }

    function getEscrowStatus() public view returns (status) {
        // ) internal view exists(escId) returns (status) {
        return escrowStatus;
    }

    function release() public payable itemIsOpen onlyMarketplace nonReentrant {
        require(
            tx.origin == buyer,
            "Only the buyer has the right to finalize trade"
        );
        TransferHelper.safeTransferLSP8(LSP8Collection, address(this), buyer, tokenId, true, '0x');
        TransferHelper.safeTransferLYX(seller, balance);
        escrowStatus = status.CONFIRMED;
    }

    function markSent(string memory _trackingID)external onlyMarketplace nonReentrant {
        require(
            tx.origin == seller,
            "Only the Seller has the right"
        );
        trackingID = _trackingID;
        escrowStatus = status.SENT;
    }

    function dispute() external onlyMarketplace nonReentrant {
        escrowStatus = status.DISPUTED;
    }



    function dissolve() external onlyMarketplace nonReentrant{
        TransferHelper.safeTransferLSP8(LSP8Collection, address(this), seller, tokenId, true, '0x');
        TransferHelper.safeTransferLYX(buyer, balance);
        escrowStatus = status.DISSOLVED;
    }

    function settle() external onlyMarketplace nonReentrant{
        TransferHelper.safeTransferLSP8(LSP8Collection, address(this), buyer, tokenId, true, '0x');
        TransferHelper.safeTransferLYX(seller, balance);
        escrowStatus = status.CONFIRMED;
    }

    function cancel() external onlyMarketplace nonReentrant {
        require( escrowStatus == status.OPEN, 'Item Already Marked Sent');
        TransferHelper.safeTransferLSP8(LSP8Collection, address(this), seller, tokenId, true, '0x');
        TransferHelper.safeTransferLYX(buyer, balance);
        escrowStatus = status.CANCELED;
    }
}