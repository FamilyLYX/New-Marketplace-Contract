// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

import {ILSP8IdentifiableDigitalAsset} from "@lukso/lsp-smart-contracts/contracts/LSP8IdentifiableDigitalAsset/ILSP8IdentifiableDigitalAsset.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {TransferHelper} from "./libraries/transferHelpers.sol";
import {Royalties, RoyaltiesInfo} from "./libraries/Royalty.sol";
import {Points} from "./libraries/Points.sol";

/**
 * @title Family Escrow Contract
 *
 */

contract FamilyMarketPlaceEscrow is ReentrancyGuard {
    address owner;
    address asset;
    bytes32 tokenId;
    address public seller;
    address public buyer;
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

    error RoyaltiesExceedThreshold(
        uint32 royaltiesThresholdPoints,
        uint256 totalPrice,
        uint256 totalRoyalties
    );

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
     * @param _familyAddress address of the fee receiver
     *
     *
     * @notice this method can only be called once Buyer commits LYX payment
     */

    constructor(
        address LSP8Address,
        bytes32 _tokenId,
        address _seller,
        address _buyer,
        uint256 amount,
        address _familyAddress
    ) {
        asset = LSP8Address;
        tokenId = _tokenId;
        seller = _seller;
        buyer = _buyer;
        timestamp = block.timestamp;
        escrowStatus = status.OPEN;
        balance = amount;
        owner = msg.sender;
        familyAddress = _familyAddress;
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

    function release(
        uint256 feeAmount,
        uint256 lastPurchasePrice,
        uint32 royaltiesThresholdPoints
    ) public payable itemIsOpen onlyMarketplace nonReentrant {
        require(
            tx.origin == buyer,
            "Only the buyer has the right to finalize trade"
        );

        (
            uint256 royaltiesTotalAmount,
            address[] memory royaltiesRecipients,
            uint256[] memory royaltiesAmounts
        ) = _calculateRoyalties(balance, royaltiesThresholdPoints);

        if (
            balance <= lastPurchasePrice &&
            !Royalties.royaltiesPaymentEnforced(asset)
        ) {
            (bool paid, ) = seller.call{value: balance - feeAmount}("");
            // if (!paid) {
            //     revert Unpaid(listingId, seller, balance - feeAmount);
            // }
        } else {
            uint256 royaltiesRecipientsCount = royaltiesRecipients.length;
            for (uint256 i = 0; i < royaltiesRecipientsCount; i++) {
                if (royaltiesAmounts[i] > 0) {
                    (bool royaltiesPaid, ) = royaltiesRecipients[i].call{
                        value: royaltiesAmounts[i]
                    }("");
                    // if (!royaltiesPaid) {
                    //     revert Unpaid(
                    //         listingId,
                    //         royaltiesRecipients[i],
                    //         royaltiesAmounts[i]
                    //     );
                    // }
                    // emit RoyaltiesPaid(
                    //     listingId,
                    //     asset,
                    //     tokenId,
                    //     royaltiesRecipients[i],
                    //     royaltiesAmounts[i]
                    // );
                }
            }
            uint256 sellerAmount = balance - feeAmount - royaltiesTotalAmount;
            (bool paid, ) = seller.call{value: sellerAmount}("");
            // if (!paid) {
            //     revert Unpaid(listingId, seller, sellerAmount);
            // }
        }

        TransferHelper.safeTransferLSP8(
            asset,
            address(this),
            buyer,
            tokenId,
            true,
            "0x"
        );
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
            asset,
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
            asset,
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
            asset,
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
            asset,
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
            asset,
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
            asset,
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
            asset,
            address(this),
            seller,
            tokenId,
            true,
            "0x"
        );
        escrowStatus = status.CANCELED;
    }

    function _calculateRoyalties(
        uint256 totalPrice,
        uint32 royaltiesThresholdPoints
    )
        internal
        view
        returns (
            uint256 totalAmount,
            address[] memory recipients,
            uint256[] memory amounts
        )
    {
        totalAmount = 0;
        RoyaltiesInfo[] memory royalties = Royalties.royalties(asset);
        recipients = new address[](royalties.length);
        amounts = new uint256[](royalties.length);
        uint256 count = royalties.length;
        for (uint256 i = 0; i < count; i++) {
            assert(Points.isValid(royalties[i].points));
            uint256 amount = Points.realize(totalPrice, royalties[i].points);
            recipients[i] = royalties[i].recipient;
            amounts[i] = amount;
            totalAmount += amount;
        }
        if (
            (royaltiesThresholdPoints != 0) &&
            (totalAmount > Points.realize(totalPrice, royaltiesThresholdPoints))
        ) {
            revert RoyaltiesExceedThreshold(
                royaltiesThresholdPoints,
                totalPrice,
                totalAmount
            );
        }
    }
}
