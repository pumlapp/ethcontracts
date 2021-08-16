// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./PumlNFT.sol";

contract PumlNFTMarket is Ownable, ReentrancyGuard {
    uint256 public commission = 0; // this is the commission in basic points that will charge the marketplace by default.
    uint256 public accumulatedCommission = 0; // this is the amount in ETH accumulated on marketplace wallet
    uint256 public totalSales = 0;

    struct Offer {
        address assetAddress; // address of the token
        uint256 tokenId; // the tokenId returned when calling "createItem"
        address payable creator; // who creates the offer
        uint256 price; // price of each token
        bool status; // true: active, false: inactive
    }

    mapping(uint256 => Offer) public offers;

    function createOffer(
        address _assetAddress,
        uint256 _tokenId,
        uint256 _price
    ) public {
        IERC721 asset = IERC721(_assetAddress);
        require(asset.ownerOf(_tokenId) == msg.sender, "Not the owner");
        require(
            asset.getApproved(_tokenId) == address(this),
            "NFT not approved"
        );

        // Could not be used to update an existing offer (#02)
        Offer memory previous = offers[_tokenId];
        require(previous.status == false, "An active offer already exists");

        // First create the offer
        Offer memory offer = Offer({
            assetAddress: _assetAddress,
            tokenId: _tokenId,
            creator: payable(msg.sender),
            price: _price,
            status: true
        });

        offers[_tokenId] = offer;
    }

    function removeFromSale(uint256 _tokenId) public {
        Offer memory offer = offers[_tokenId];
        require(msg.sender == offer.creator, "You are not the owner");
        offer.status = false;
        offers[_tokenId] = offer;
    }

    // Changes the default commission. Only the owner of the marketplace can do that. In basic points
    function setCommission(uint256 _commission) public onlyOwner {
        require(_commission <= 5000, "Commission too high");
        commission = _commission;
    }

    // Event triggered when buyer claims the NFT
    event Claim(uint256 auctionIndex, address claimer);

     // Event triggered when a royalties payment is generated on sale
    event Royalties(address receiver, uint256 amount);

    // Event triggered when a payment to the owner is generated on sale
    event PaymentToOwner(
        address receiver,
        uint256 amount,
        uint256 commission,
        uint256 royalties
    );

    function buy(uint256 _tokenId) public payable nonReentrant returns (bool) {
        address buyer = msg.sender;
        uint256 paidPrice = msg.value;

        Offer memory offer = offers[_tokenId];
        require(offer.status == true, "NFT not in direct sale");

        uint256 price = offer.price;
        require(paidPrice >= price, "Price is not enough");

        emit Claim(_tokenId, buyer);

        PumlNFT asset = PumlNFT(offer.assetAddress);
        asset.safeTransferFrom(offer.creator, buyer, _tokenId);

        // now, pay the amount - commission - royalties to the auction creator
        address payable creatorNFT = payable(asset.getCreator(_tokenId));

        uint256 commissionToPay = (paidPrice * commission) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT != offer.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay = (paidPrice * asset.getRoyalties(_tokenId)) / 10000;

            (bool success, ) = creatorNFT.call{value: royaltiesToPay}("");
            require(success, "Transfer failed.");

            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay = paidPrice - commissionToPay - royaltiesToPay;

        (bool success2, ) = offer.creator.call{value: amountToPay}("");
        require(success2, "Transfer failed.");
        emit PaymentToOwner(
            offer.creator,
            amountToPay,
            commissionToPay,
            royaltiesToPay
        );

        accumulatedCommission = accumulatedCommission + commissionToPay;

        offer.status = false;
        offers[_tokenId] = offer;

        totalSales = totalSales + msg.value;

        return true;
    }
}
