// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract PumlNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    string private baseTokenURI;

    struct TokenData {
        address payable creator; // creator of the NFT
        uint256 royalties; // royalties to be paid to NFT creator on a resale. In basic points
        string lockedContent; // Content that is locked until the token is sold, and then will be visible to the owner
    }

    mapping(uint256 => TokenData) tokenMetadata;

    constructor(string memory _baseTokenURI) ERC721("PumlNFT", "PNFT") {
        _baseTokenURI = baseTokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function getCreator(uint256 _tokenId) public view returns (address) {
        return tokenMetadata[_tokenId].creator;
    }

    function getRoyalties(uint256 _tokenId) public view returns (uint256) {
        return tokenMetadata[_tokenId].royalties;
    }

    // creator mint his token
    function mint(
        string memory _tokenURI, // token URI without baseURI
        uint256 _royalties, // creator's share get paid from buyer - 100 means 1%
        string memory _lockedContent // the content which only owner can see
    ) public returns (uint256) {
        tokenIds.increment();

        uint256 newItemId = tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, _tokenURI);

        TokenData memory metadata = TokenData({
            creator: payable(msg.sender),
            royalties: _royalties,
            lockedContent: _lockedContent
        });
        tokenMetadata[newItemId] = metadata;

        return newItemId;
    }

    // get locked content
    function unlockContent(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        require(this.ownerOf(_tokenId) == msg.sender, "PumlNFT: Not the owner");
        return tokenMetadata[_tokenId].lockedContent;
    }
}
