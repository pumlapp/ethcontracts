// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

// ERC721URIStorage is the contract from openzeppelin for v0.8 that includes the metadata 
contract PumlNFT is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Data of each NFT
    struct TokenData {
        address payable creator; // creator of the NFT
        uint256 royalties;       // royalties to be paid to NFT creator on a resale. In basic points
        string lockedContent;    // Content that is locked until the token is sold, and then will be visible to the owner
    }
    mapping(uint256 => TokenData) tokens;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function getCreator(uint256 _tokenId) public view returns (address) {
        return tokens[_tokenId].creator;
    }

    // returns in basic points the royalties of a token
    function getRoyalties(uint256 _tokenId) public view returns (uint256) {
        return tokens[_tokenId].royalties;
    }

    // mints the NFT and save the data in the "tokens" map
    function createItem(string memory tokenURI, uint256 _royalties, string memory _lockedContent)
        public
        returns (uint256)
    {
        require(_royalties <=5000, "Max royalties are 50%");

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        tokens[newItemId] = TokenData({ creator: payable(msg.sender), royalties: _royalties, lockedContent:_lockedContent});
    
        return newItemId;
    }

    // returns the string "locked", only available for the owner
    function unlockContent(uint256 _tokenId) public view returns (string memory)
    {
        require(this.ownerOf(_tokenId) == msg.sender, "Not the owner");
        return tokens[_tokenId].lockedContent;
    }
}
