// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

//import "./AddressUtils.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PumlNFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Engine is Ownable {
    using SafeMath for uint256;

    // Event triggered when an auction is created
    event AuctionCreated(uint256 _index, address _creator, address _asset);
    // Event triggered when an auction receives a bid
    event AuctionBid(uint256 _index, address _bidder, uint256 amount);
    // Event triggered when an ended auction winner claims the NFT
    event Claim(uint256 auctionIndex, address claimer);
    // Event triggered when an auction received a bid that implies sending funds back to previous best bidder
    event ReturnBidFunds(uint256 _index, address _bidder, uint256 amount);
    // Event triggered when a royalties payment is generated, either on direct sales or on auctions
    event Royalties(address receiver, uint256 amount);
    // Event triggered when a payment to the owner is generated, either on direct sales or on auctions.assetAddress
    // This event is useful to check that all the payments funds are the right ones.
    event PaymentToOwner(
        address receiver,
        uint256 amount,
        uint256 paidByCustomer,
        uint256 commission,
        uint256 royalties,
        uint256 safetyCheckValue
    );

    // Status of an auction, calculated using the start date, the duration and the current timeblock
    enum Status {pending, active, finished}
    // Data of an auction
    struct Auction {
        address assetAddress;               // token address
        uint256 assetId;                    // token id
        address payable creator;            // creator of the auction, which is the token owner
        uint256 startTime;                  // time (unix, in seconds) where the auction will start
        uint256 duration;                   // duration in seconds of the auction
        uint256 currentBidAmount;           // amount in ETH of the current bid amount
        address payable currentBidOwner;    // address of the user who places the best bid
        uint256 bidCount;                   // number of bids of the auction
    }
    Auction[] public auctions;

    uint256 public commission = 0; // this is the commission in basic points that will charge the marketplace by default.
    uint256 public accumulatedCommission = 0; // this is the amount in ETH accumulated on marketplace wallet

    struct Offer {
        address assetAddress;       // address of the token
        uint256 tokenId;            // the tokenId returned when calling "createItem"
        address payable creator;    // who creates the offer
        uint256 price;              // price of each token
        bool isOnSale;              // is on sale or not
        bool isAuction;             // is this offer is for an auction
        uint256 idAuction;          // the id of the auction
    }
    mapping(uint256 => Offer) public offers;

    // Every time a token is put on sale, an offer is created. An offer can be a direct sale, an auction
    // or a combination of both.
    function createOffer(
        address _assetAddress,  // address of the token
        uint256 _tokenId,       // tokenId
        bool _isDirectSale,     // true if can be bought on a direct sale
        bool _isAuction,        // true if can be bought in an auction
        uint256 _price,         // price that if paid in a direct sale, transfers the NFT
        uint256 _startPrice,    // minimum price on the auction
        uint256 _startTime,     // time when the auction will start. Check the format with frontend
        uint256 _duration       // duration in seconds of the auction
    ) public {
        ERC721 asset = ERC721(_assetAddress);
        require(asset.ownerOf(_tokenId) == msg.sender, "Not the owner");
        require(
            asset.getApproved(_tokenId) == address(this),
            "NFT not approved"
        );
        // First create the offer
        Offer memory offer =
            Offer({
                assetAddress: _assetAddress,
                tokenId: _tokenId,
                creator: payable(msg.sender),
                price: _price,
                isOnSale: _isDirectSale,
                isAuction: _isAuction,
                idAuction: 0
            });
        // only if the offer has the "is_auction" flag, add the auction to the list
        if (_isAuction) {
            offer.idAuction = createAuction(
                _assetAddress,
                _tokenId,
                _startPrice,
                _startTime,
                _duration
            );
        }
        offers[_tokenId] = offer;
    }

    // returns the auctionId from the offerId
    function getAuctionId(uint256 _tokenId) public view returns (uint256) {
        Offer memory offer = offers[_tokenId];
        return offer.idAuction;
    }

    // this method returns the current date and time of the blockchain. Used also to check the contract is alive
    function ahora() public view returns (uint256) {
        return block.timestamp;
    }

    // Remove an auction from the offer that did not have previous bids. Beware could be a direct sale
    function removeFromAuction(uint256 _tokenId) public {
        Offer memory offer = offers[_tokenId];
        require(msg.sender == offer.creator, "You are not the owner");
        Auction memory auction = auctions[offer.tokenId];
        require(auction.bidCount == 0, "Bids existing");
        offer.isAuction = false;
        offer.idAuction = 0;
        offers[_tokenId] = offer;
    }

    // remove a direct sale from an offer. Beware that could be an auction for the token
    function removeFromSale(uint256 _tokenId) public {
        Offer memory offer = offers[_tokenId];
        require(msg.sender == offer.creator, "You are not the owner");
        offer.isOnSale = false;
        offers[_tokenId] = offer;
    }

    // Changes the default commission. Only the owner of the marketplace can do that. In basic points
    function setCommission(uint256 _commission) public onlyOwner {
        commission = _commission;
    }

    // called in a direct sale by the customer. Transfer the nft to the customer, the royalties (if any)
    // to the token creator, the commission for the marketplace is keeped on the contract and the remaining
    // funds are transferred to the token owner.
    // is there is an auction open, the last bid amount is sent back to the last bidder
    // After that, the offer is cleared.
    function buy(uint256 _tokenId) external payable {
        address buyer = msg.sender;
        uint256 paidPrice = msg.value;

        Offer memory offer = offers[_tokenId];
        require(offer.isOnSale == true, "NFT not in direct sale");
        uint256 price = offer.price;
        require(paidPrice >= price, "Price is not enough");

        emit Claim(_tokenId, buyer);
        PumlNFT asset = PumlNFT(offer.assetAddress);
        asset.transferFrom(offer.creator, buyer, _tokenId);

        // now, pay the amount - commission - royalties to the auction creator
        address payable creatorNFT = payable(asset.getCreator(_tokenId));

        uint256 commissionToPay = (paidPrice.mul(commission)) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT != offer.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay = (paidPrice.mul(asset.getRoyalties(_tokenId))) / 10000;
            creatorNFT.transfer(royaltiesToPay);
            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay = paidPrice.sub(commissionToPay).sub(royaltiesToPay);

        offer.creator.transfer(amountToPay);
        emit PaymentToOwner(
            offer.creator,
            amountToPay, 
            paidPrice,
            commissionToPay,
            royaltiesToPay,
            amountToPay + ((paidPrice * commission) / 10000) // using safemath will trigger an error because of stack size
        );

        // is there is an auction open, we have to give back the last bid amount to the last bidder
        if (offer.isAuction == true) {
            Auction memory auction = auctions[offer.idAuction];
            if (auction.currentBidAmount != 0) {
                // return funds to the previuos bidder
                auction.currentBidOwner.transfer(auction.currentBidAmount);
                emit ReturnBidFunds(
                    offer.idAuction,
                    auction.currentBidOwner,
                    auction.currentBidAmount
                );
            }
        }

        accumulatedCommission = accumulatedCommission.add(commissionToPay);

        offer.isAuction = false;
        offer.isOnSale = false;
        offers[_tokenId] = offer;
    }

    // Creates an auction for a token. It is linked to an offer
    function createAuction(
        address _assetAddress, // address of the PumlNFT token
        uint256 _assetId, // id of the NFT
        uint256 _startPrice, // minimum price
        uint256 _startTime, // time when the auction will start. Check with frontend because is unix time in seconds, not millisecs!
        uint256 _duration // duration in seconds of the auction
    ) private returns (uint256) {
        if (_startTime == 0) {
            _startTime = block.timestamp;
        }

        Auction memory auction =
            Auction({
                creator: payable(msg.sender),
                assetAddress: _assetAddress,
                assetId: _assetId,
                startTime: _startTime,
                duration: _duration,
                currentBidAmount: _startPrice,
                currentBidOwner: payable(address(0)),
                bidCount: 0
            });
        auctions.push(auction);
        uint256 index = auctions.length.sub(1);

        emit AuctionCreated(index, auction.creator, auction.assetAddress);

        return index;
    }

    // At the end of the call, the amount is saved on the marketplace wallet and the previous bid amount is returned to old bidder
    // except in the case of the first bid, as could exists a minimum price set by the creator as first bid.
    function bid(uint256 auctionIndex) public payable {
        Auction storage auction = auctions[auctionIndex];
        require(auction.creator != address(0));
        require(isActive(auctionIndex));
        require(msg.value > auction.currentBidAmount, "Bid too low");
        // we got a better bid. Return funds to the previous best bidder
        // and register the sender as `currentBidOwner`

        // this check is for not transferring back funds on the first bid, as the fist bid is the minimum price set by the auction creator
        if (
            auction.currentBidAmount != 0 &&
            auction.currentBidOwner != auction.creator
        ) {
            // return funds to the previuos bidder
            auction.currentBidOwner.transfer(auction.currentBidAmount);
            emit ReturnBidFunds(
                auctionIndex,
                auction.currentBidOwner,
                auction.currentBidAmount
            );
        }
        // register new bidder
        auction.currentBidAmount = msg.value;
        auction.currentBidOwner = payable(msg.sender);
        auction.bidCount = auction.bidCount.add(1);

        emit AuctionBid(auctionIndex, msg.sender, msg.value);
    }

    function getTotalAuctions() public view returns (uint256) {
        return auctions.length;
    }

    function isActive(uint256 _auctionIndex) public view returns (bool) {
        return getStatus(_auctionIndex) == Status.active;
    }

    function isFinished(uint256 _auctionIndex) public view returns (bool) {
        return getStatus(_auctionIndex) == Status.finished;
    }

    // The auctions did not be affected if the current time is 15 seconds wrong
    // So, according to Consensys security advices, it is safe using block.timestamp
    function getStatus(uint256 _auctionIndex) public view returns (Status) {
        Auction storage auction = auctions[_auctionIndex];
        if (block.timestamp < auction.startTime) {
            return Status.pending;
        } else if (block.timestamp < auction.startTime.add(auction.duration)) {
            return Status.active;
        } else {
            return Status.finished;
        }
    }

    // returns the end date of the auction, in unix time using seconds
    function endDate(uint256 _auctionIndex) public view returns (uint256) {
        Auction storage auction = auctions[_auctionIndex];
        return auction.startTime.add(auction.duration);
    }

    // returns the user with the best bid until now on an auction
    function getCurrentBidOwner(uint256 _auctionIndex) public view returns (address)
    {
        return auctions[_auctionIndex].currentBidOwner;
    }

    // returns the amount in ETH of the best bid until now on an auction
    function getCurrentBidAmount(uint256 _auctionIndex) public view returns (uint256)
    {
        return auctions[_auctionIndex].currentBidAmount;
    }

    // returns the number of bids of an auction (0 by default)
    function getBidCount(uint256 _auctionIndex) public view returns (uint256) {
        return auctions[_auctionIndex].bidCount;
    }

    // returns the winner of an auction once the auction finished
    function getWinner(uint256 auctionIndex) public view returns (address) {
        require(isFinished(auctionIndex), "Auction not finished yet");
        return auctions[auctionIndex].currentBidOwner;
    }
 
    // called when the auction is finished by the user who won the auction
    // transfer the nft to the caller, the royalties (if any) to the nft creator
    // the commission of the marketplace is calculated, and the remaining funds
    // are transferred to the token owner
    // After this, the offer is disabled
    function claimAsset(uint256 auctionIndex) public {
        require(isFinished(auctionIndex), "The auction is still active");
        Auction storage auction = auctions[auctionIndex];

        address winner = getWinner(auctionIndex);
        require(winner == msg.sender, "You are not the winner of the auction");

        // the token could be sold in direct sale or the owner cancelled the auction
        Offer memory offer = offers[auction.assetId];
        require(offer.isAuction == true, "NFT not in auction");

        PumlNFT asset = PumlNFT(auction.assetAddress);
        asset.transferFrom(auction.creator, winner, auction.assetId);

        emit Claim(auctionIndex, winner);

        // now, pay the amount - commission - royalties to the auction creator
        address payable creatorNFT = payable(asset.getCreator(auction.assetId));
        uint256 commissionToPay =
            (auction.currentBidAmount.mul(commission)) / 10000;
        uint256 royaltiesToPay = 0;
        if (creatorNFT != auction.creator) {
            // It is a resale. Transfer royalties
            royaltiesToPay =
                (auction.currentBidAmount.mul(asset.getRoyalties(auction.assetId))) /
                10000;
            creatorNFT.transfer(royaltiesToPay);
            emit Royalties(creatorNFT, royaltiesToPay);
        }
        uint256 amountToPay =
            auction.currentBidAmount.sub(commissionToPay).sub(royaltiesToPay);

        auction.creator.transfer(amountToPay);
        emit PaymentToOwner(
            auction.creator,
            amountToPay,
            auction.currentBidAmount,
            commissionToPay,
            royaltiesToPay,
            amountToPay + commissionToPay + royaltiesToPay
        );

        accumulatedCommission = accumulatedCommission.add(commissionToPay);

        offer.isAuction = false;
        offer.isOnSale = false;
        offers[auction.assetId] = offer;
    }

    // This method is only callable by the marketplace owner and transfer funds from
    // the marketplace to the caller. 
    // It us used to move the funds from the marketplace to the investors
    function extractBalance() public onlyOwner {
        address payable me = payable(msg.sender);
        me.transfer(accumulatedCommission);
        accumulatedCommission = 0;
    }
}
