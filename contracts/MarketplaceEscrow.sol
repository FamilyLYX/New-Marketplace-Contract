// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

/**
 * @title Family Escrow Contract
 *
 */


contract FamilyMarketPlaceEscrow{

    address LSP8Collection;
    bytes32 tokenId;
    address seller;
    address buyer;
    uint256 balance;
    // address OGminter;
    uint256 timestamp;
    uint256 escrowId;
    status escrowStatus;

    enum status {
        OPEN, // 0, trade is ongoing
        CONFIRMED, // 1, trade can be confirmed
        CANCELED, // 2, trade has been canceled
        DISPUTED, // 3, trade is in dispute - set period before assets are withheld
        DISSOLVED // 4, trade has been closed
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
        require(escrowStatus != status.DISSOLVED, "Escrow item has been closed.");
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

    function release() public payable itemIsOpen {
        require(
            msg.sender == buyer,
            "Only the buyer has the right to finalize trade"
        );
        payable(seller).transfer(balance);
        // IFamilyNft(LSP8Collection).transfer(
        //     address(this),
        //     buyer,
        //     tokenId,
        //     true,
        //     ""
        // );
        escrowStatus = status.DISSOLVED;
    }

    function refund() public payable {}

    function withdraw() public payable {}
    
}