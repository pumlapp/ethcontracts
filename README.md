# ethcontracts

# PumlNFT.sol - Puml NFT Token Contract

- mint NFT token
mint(
    string memory _tokenURI, // token URI without baseURI
    uint256 _royalties, // creator's share get paid from buyer - 100 means 1%
    string memory _lockedContent // the content which only owner can see
) returns (uint256) // new Token's id

# PumlNFTMarket.sol - Puml NFT Market Contract