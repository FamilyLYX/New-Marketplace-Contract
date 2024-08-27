// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {ILSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TransferHelper} from "./libraries/transferHelpers.sol";

/**
 * @title Family Escrow Contract
 *
 */

contract FamilyMarketPlaceEscrow is ReentrancyGuard {
    address owner;
    address LSP8Collection;
    bytes32 tokenId;
    address seller;
    address buyer;
    uint256 balance;

    address familyAddress;
    // address OGminter;
    uint256 timestamp;
    uint256 escrowId;
    status escrowStatus;
    string trackingID;
    bool public isEscrow = true;

    uint8 platformFee = 250; // fee/100 would give the percentage

    struct DecodedRoyalty {
        // bytes4 byteValue;
        address addrValue;
        uint256 numValue;
    }

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
        owner = msg.sender;
    }

    function parseRoyalty(
        bytes memory royalty
    ) public pure returns (DecodedRoyalty memory royaltyInstance) {
        require(royalty.length >= 20, "Royalty data is too short"); // Ensure the royalty bytes are long enough

        // Extract the relevant bytes for addrValue and numValue
        bytes14 addrBytes;
        bytes12 numBytes;

        // Extract bytes for addrValue (assuming the relevant 14 bytes start from index 0)
        assembly {
            addrBytes := mload(add(royalty, 20))
        }
        // Convert bytes14 to bytes32, then to uint256, and finally to address
        royaltyInstance.addrValue = address(
            uint160(uint256(bytes32(addrBytes)))
        );

        // Extract bytes for numValue (assuming the relevant 12 bytes start from index 14)
        assembly {
            numBytes := mload(add(royalty, 32))
        }
        // Convert bytes12 to bytes32, then to uint256, and finally to uint96
        royaltyInstance.numValue = uint96(uint256(bytes32(numBytes)));
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
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            buyer,
            tokenId,
            true,
            "0x"
        );

        bytes memory royalty = ILSP8IdentifiableDigitalAsset(LSP8Collection)
            .getData(
                0xc0569ca6c9180acc2c3590f36330a36ae19015a19f4e85c28a7631e3317e6b9d
            );

        uint256 payment = balance;

        if (royalty.length > 0) {
            DecodedRoyalty memory royaltyParts = parseRoyalty(royalty);
            uint256 royaltyFee = ((royaltyParts.numValue / 1000) * balance) /
                100;
            TransferHelper.safeTransferLYX(royaltyParts.addrValue, royaltyFee);

            payment -= royaltyFee;
        }

        uint256 fee = (balance * (platformFee / 100)) / 100;
        TransferHelper.safeTransferLYX(familyAddress, fee);
        TransferHelper.safeTransferLYX(seller, payment - fee);
        escrowStatus = status.CONFIRMED;
    }

    function releaseFiat()
        public
        payable
        itemIsOpen
        onlyMarketplace
        nonReentrant
    {
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            buyer,
            tokenId,
            true,
            "0x"
        );
        escrowStatus = status.CONFIRMED;
    }

    function markSent(
        string memory _trackingID
    ) external onlyMarketplace nonReentrant {
        require(tx.origin == seller, "Only the Seller has the right");
        trackingID = _trackingID;
        escrowStatus = status.SENT;
    }

    function dispute() external onlyMarketplace nonReentrant {
        escrowStatus = status.DISPUTED;
    }

    function dissolve() external onlyMarketplace nonReentrant {
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            seller,
            tokenId,
            true,
            "0x"
        );
        TransferHelper.safeTransferLYX(buyer, balance);
        escrowStatus = status.DISSOLVED;
    }

    function dissolveFiat() external onlyMarketplace nonReentrant {
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            seller,
            tokenId,
            true,
            "0x"
        );
        escrowStatus = status.DISSOLVED;
    }

    function settle() external onlyMarketplace nonReentrant {
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            buyer,
            tokenId,
            true,
            "0x"
        );
        TransferHelper.safeTransferLYX(seller, balance);
        escrowStatus = status.CONFIRMED;
    }

    function settleFiat() external onlyMarketplace nonReentrant {
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            buyer,
            tokenId,
            true,
            "0x"
        );
        TransferHelper.safeTransferLYX(seller, balance);
        escrowStatus = status.CONFIRMED;
    }

    function cancel() external onlyMarketplace nonReentrant {
        require(escrowStatus == status.OPEN, "Item Already Marked Sent");
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            seller,
            tokenId,
            true,
            "0x"
        );
        TransferHelper.safeTransferLYX(buyer, balance);
        escrowStatus = status.CANCELED;
    }

    function cancelFiat() external onlyMarketplace nonReentrant {
        require(escrowStatus == status.OPEN, "Item Already Marked Sent");
        TransferHelper.safeTransferLSP8(
            LSP8Collection,
            address(this),
            seller,
            tokenId,
            true,
            "0x"
        );
        escrowStatus = status.CANCELED;
    }
}
