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

    // seller call this to make his offer for token sale
    function createOffer(
        address _assetAddress, // PumlNFT's address
        uint256 _tokenId, // token's id
        uint256 _price // sale price in ether
    ) public {
        IERC721 asset = IERC721(_assetAddress);
        require(
            asset.ownerOf(_tokenId) == msg.sender,
            "PumlNFTMarket: You are not the owner"
        );
        require(
            asset.getApproved(_tokenId) == address(this),
            "PumlNFTMarket: NFT not approved"
        );

        // Could not be used to update an existing offer (#02)
        Offer memory previous = offers[_tokenId];
        require(
            previous.status == false,
            "PumlNFTMarket: An active offer already exists"
        );

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

    // remove offer for sale
    function removeFromSale(uint256 _tokenId) public {
        Offer memory offer = offers[_tokenId];
        require(
            msg.sender == offer.creator,
            "PumlNFTMarket: You are not the owner"
        );
        offer.status = false;
        offers[_tokenId] = offer;
    }

    // set the commission for market - 100 means 1%, maximum is set by 50%
    function setCommission(uint256 _commission) public onlyOwner {
        require(_commission <= 5000, "PumlNFTMarket: Commission too high");
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

    // buy NFT token
    function buy(uint256 _tokenId) public payable nonReentrant returns (bool) {
        address buyer = msg.sender;
        uint256 paidPrice = msg.value;

        Offer memory offer = offers[_tokenId];
        require(offer.status == true, "PumlNFTMarket: NFT not on sale");

        uint256 price = offer.price;
        require(paidPrice >= price, "PumlNFTMarket: Price is not enough");

        emit Claim(_tokenId, buyer);

        PumlNFT asset = PumlNFT(offer.assetAddress);
        asset.safeTransferFrom(offer.creator, buyer, _tokenId);

        // now, pay the amount - commission - royalties to creator
        address payable creatorNFT = payable(asset.getCreator(_tokenId));

        uint256 commissionToPay = (paidPrice * commission) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT != offer.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay = (paidPrice * asset.getRoyalties(_tokenId)) / 10000;

            (bool success, ) = creatorNFT.call{value: royaltiesToPay}("");
            require(success, "PumlNFTMarket: Transfer roaylties failed.");

            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay = paidPrice - commissionToPay - royaltiesToPay;

        (bool success2, ) = offer.creator.call{value: amountToPay}("");
        require(success2, "PumlNFTMarket: Transfer payment failed.");

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
