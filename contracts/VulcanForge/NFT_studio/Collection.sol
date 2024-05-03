// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Collection is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter public _tokenIdCounter;
    uint256 public _maxSupply;
    uint256 public fixedTotalSupply;
    bool public limitedEdition;
    uint256 public currentlyMintedTokens;
    mapping(uint256 => bool) public burnedTokens;
    uint256[] public availableBurnedSlots;

    constructor(string memory name, string memory symbol, address creator, uint256 maxSupply, bool _limitedEdition)Ownable(creator)
        ERC721(name, symbol)
    {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");

        _tokenIdCounter.increment(); 

        if (_limitedEdition == true) {
            require(maxSupply > 0, "Max supply must be greater than zero");
            limitedEdition = _limitedEdition;
            _maxSupply = maxSupply;
            fixedTotalSupply = maxSupply;
        }
    }

    function safeMint(address to, string memory uri) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        uint256 tokenId = getNextAvailableTokenId();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function bulkMint(address to, string[] memory uris) external onlyOwner {
        require(to != address(0), "Invalid recipient address");
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = getNextAvailableTokenId();
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
        }
    }

    function getNextAvailableTokenId() internal returns (uint256) {
        uint256 tokenId;
        if (limitedEdition == true) {
            // If there are available burned token slots, use one of them
            if (availableBurnedSlots.length > 0) {
                tokenId = availableBurnedSlots[availableBurnedSlots.length - 1];
                availableBurnedSlots.pop();
                burnedTokens[tokenId] = false; // Mark the burned token as unused
            } else {
                // If no burned tokens are available, check if max supply has been reached
                require(currentlyMintedTokens < _maxSupply, "Maximum supply has been reached.");
                tokenId = _tokenIdCounter.current();
                _tokenIdCounter.increment();
            }
        } else {
            tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
        }

        currentlyMintedTokens++;
        return tokenId;
    }

    function bulkTransfer(address from, address to, uint256[] memory tokenIds) external onlyOwner {
        require(from != address(0), "Invalid sender address");
        require(to != address(0), "Invalid recipient address");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeTransferFrom(from, to, tokenIds[i]);
        }
    }

    function burn(uint256 tokenId) external onlyOwner {
        require(tokenId <= _maxSupply, "Invalid tokenId");
        require(tokenId > 0, "TokenId must be greater than zero");
        require(!burnedTokens[tokenId], "Token already burned");

        super._burn(tokenId);
        burnedTokens[tokenId] = true;
        availableBurnedSlots.push(tokenId);
        currentlyMintedTokens--;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function bulkTransferNFT(address contractAddress, address from, address[] memory to, uint256[] memory tokenIds  ) public {
        require(from != address(0), "Invalid sender address");
        require(contractAddress == address(this), "Contract Address should be this contract");
        require(to.length == tokenIds.length, "Length of recipents and tokenId should be same");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(to[i] != address(0), "Invalid recipient address in array");
            safeTransferFrom(from, to[i], tokenIds[i]);
        }
    }
}