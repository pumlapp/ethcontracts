# ethcontracts

# PumlNFT.sol - Puml NFT Token Contract

1. createItem (string _tokenURI, uint256 _royalties, string _lockedContent)
- _tokenURI : NFT token's URI without baseURI, baseURI has already set when deployed
- _royalties : payment for creator, set by percentage of sale price, 100 means 1%
- _lockedContent : set the content which only owner can see
- returns created Token's ID

2. unlockContent(uint256 _tokenId)
- _tokenId : Token's ID returned from mint function
- returns token's locked content for owner

3. getCreator(uint256 _tokenId)
- _tokenId : Token's ID returned from mint function
- returns the address of token creator

4. getRoyalties(uint256 _tokenId)
- _tokenId : Token's ID returned from mint function
- returns the royalty of created token

# Engine.sol - Puml NFT Market Contract

1. setCommission(uint256 _commission)
- _commission : set the commission for market - 100 means 1%, maximum is set by 50%

2. createOffer(address _assetAddress, uint256 _tokenId, uint256 _price)
- _assetAddress : PumlNFT's contract address
- _tokenId : Token's ID
- _price : sale price in ether

3. removeFromSale(uint256 _tokenId)
- _tokenId : Token's ID

4. buy(uint256 _tokenId, uint256 _puml)
- _tokenId : Token's ID
- _puml: offer price in pumlx
- returns bool - true : success

5. getAuctionId(uint256 _tokenId)
- _tokenId : Token's ID
- returns the auctionId

6. createAuction(address _assetAddress, uint256 _assetId, uint256 _startPrice, uint256 _startTime, uint256 _duration)
- _assetAddress: address of the pumlNFT token
- _assetId: id of the NFT
- _startPrice: minium price
- _startTime: time when the auction will start. Check with frontend because is unix time in seconds, not millisecs!
- _duration: duration in seconds of the auction
- returns auctions length

7. bid(uint256 auctionIndex, uint256 _puml)
- auctionIndex: the index of auction
- _puml: offer bid price in pumlx
- returns bool - true : success

8. getTotalAuctions()
- returns auctions length

9. isActive(uint256 _auctionIndex)
- _auctionIndex: the index of auction
- returns bool - true

10. getStatus(uint256 _auctionIndex)
- _auctionIndex: the index of auction
- returns enum Status: pending/active/finished

11. getCurrentBidOwner(uint256 _auctionIndex)
 - _auctionIndex: the index of auction
 - returns the address of bidder
 
12. getCurrentBidAmount(uint256 _auctionIndex)
 - _auctionIndex: the index of auction
 - returns the bid price of token
  
13. getWinner(uint256 auctionIndex)
 - _auctionIndex: the index of auction
 - returns the address of bid winner
	
14. stakeNFT(address _assetAddress, uint256[] memory tokenIds)
- _assetAddress: the address of collection
- tokensIds: the id array of stake nfts

15. withdrawNFT(address _assetAddress, uint256[] memory tokenIds, uint256 _claimAmount)
- _assetAddress: the address of collection
- tokensIds: the id array of stake nfts
- _claimAmount: the amount to claim

# PumlStake.sol - Puml NFT Stake/Unstake Contract

1. getStakedAssets(address _contractAddress, uint256 _tokenId)
- _contractAddress: address of the nft contract
- _tokenId : Token's ID
- returns address of token

2. setStakedAssets(address _contractAddress, uint256 _tokenId, address _staker)
- _contractAddress: address of the nft contract
- _tokenId : Token's ID
- _staker: address of staker

3. setBalancesNFT(address _address, uint256 _amount, bool param)
- _address: address of the token
- _amount: amount of token to stake/unstake
- param: true- stake, false-unstake

4. nftRewardClaim(address _address, uint256 _claimAmount)
- _address: address of the token
- _claimAmount: amount to claim

5. getUserData(address account)
- account: address of call

6. setTransferPuml(address _from, address _to, uint256 _amount)
- _from: address from which to transfer pumlx
- _to: address to which to transfer pumlx
- _amount: amount of pumlx to transfer

7. setDepositPuml(address _from, uint256 _amount)
- _from: address where to deposit pumlx
- _amount: amount to deposit pumlx

8. stake(uint256 amount, uint256 stakeamount)
- amount: amount of pumlx to stake
- stakeamount: amount (toWei) of pumlx to stake

9. withdraw(uint256 amount, uint256 unstakeamount, uint256 claimAmount)
- amount: amount of pumlx to unstake
- unstakeamount: amount (toWei) of pumlx to unstake
- claimAmount: amount to claim

10. collectFeeReward(uint256 collectAmount, uint256 totalCollectAmount)
- collectAmount: Fee reward amount to collect
- totalCollectAmount: total fee reward amount stored

11. claimApi(address claimer, uint256 reward)
- claimer: address of claimer
- reward: reward to claim

12. transferPuml(address _to, uint256 _amount)
- _to: address where to transfer pumlx to
- _amount: amount of pumlx to transfer

13. pickPuml(address _to, uint256 _amount)
- _to: address where to transfer pumlx to
- _amount: amount of pumlx to transfer

14. depositPuml(uint256 _amount)
- _amount: amount of pumlx to transfer

# Please reference source code and comments.