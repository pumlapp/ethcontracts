# ethcontracts

# PumlNFT.sol - Puml NFT Token Contract

1. mint (string _tokenURI, uint256 _royalties, string _lockedContent)
- _tokenURI : NFT token's URI without baseURI, baseURI has already set when deployed
- _royalties : payment for creator, set by percentage of sale price, 100 means 1%
- _lockedContent : set the content which only owner can see
- returns created Token's ID

2. unlockContent(uint256 _tokenId)
- _tokenId : Token's ID returned from mint function
- returns token's locked content for owner

# PumlNFTMarket.sol - Puml NFT Market Contract

1. setCommission(uint256 _commission)
- _commission : set the commission for market - 100 means 1%, maximum is set by 50%

2. createOffer(address _assetAddress, uint256 _tokenId, uint256 _price)
- _assetAddress : PumlNFT's contract address
- _tokenId : Token's ID
- _price : sale price in ether

3. removeFromSale(uint256 _tokenId)
- _tokenId : Token's ID

4. buy(uint256 _tokenId)
- _tokenId : Token's ID
- returns bool - true : success

Please reference source code and comments.