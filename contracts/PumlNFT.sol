// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PumlNFT is ERC721, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;
    string private baseTokenURI;

    struct Metadata {
        uint256 tokenId;
        uint256 tokenType;
    }

    mapping(uint256 => Metadata) tokenMetadata;

    /**
     * @notice The constructor for the Staking Token.
     */
    constructor(string memory _baseTokenURI) ERC721("PumlNFT", "PNFT") {
        _baseTokenURI = baseTokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function mint(address _to, uint256 _tokenType)
        public
        onlyOwner
        returns (uint256)
    {
        tokenIds.increment();
        uint256 newItemId = tokenIds.current();
        Metadata memory metadata = Metadata(newItemId, _tokenType);
        tokenMetadata[newItemId] = metadata;
        _mint(_to, newItemId);
        return newItemId;
    }
}
