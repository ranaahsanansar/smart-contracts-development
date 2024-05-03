// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "./interfaces/IERC6551Account.sol";

import "./lib/MinimalReceiver.sol";
import "./lib/ERC6551AccountLib.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract ERC6551Account is IERC165, IERC1271, IERC6551Account {
    uint256 public nonce;


    uint256 public test;

    function testing() public {
        test +=1;
    }

    receive() external payable {}

    function executeCall(
        address to,
        uint256 value,
        bytes calldata data
    ) external payable returns (bytes memory result) {
        require(msg.sender == owner(), "Not token owner");

        ++nonce;

        emit TransactionExecuted(to, value, data);

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    function token()
        external
        view
        returns (
            uint256,
            address,
            uint256
        )
    {
        return ERC6551AccountLib.token();
    }

    function owner() public pure returns (address) {
        // (uint256 chainId, address tokenContract, uint256 tokenId) = this.token();
        // if (chainId != block.chainid) return address(0);

        // return IERC721(tokenContract).ownerOf(tokenId);
        return 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    }

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return (interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC6551Account).interfaceId);
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external
        view
        returns (bytes4 magicValue)
    {
        bool isValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isValid) {
            return IERC1271.isValidSignature.selector;
        }

        return "";
    }

    function safeTransferFrom721(address from, address to, uint256 tokenId, address contractAddress) public{
        require(msg.sender == owner(), "Not token owner");
        return IERC721(contractAddress).safeTransferFrom(from, to, tokenId);
    }

    // function transferFrom721(address from, address to, uint256 tokenId, address contractAddress) public {
    //     require(msg.sender == owner(), "Not token owner");
    //     return IERC721(contractAddress).transferFrom(from, to, tokenId);
    // }

    function approve721(address to, uint256 tokenId, address contractAddress) public {
        require(msg.sender == owner(), "Not token owner");
        return IERC721(contractAddress).approve(to, tokenId);
    }

    function setApprovalForAll721(address operator, bool approved, address contractAddress) public {
        require(msg.sender == owner(), "Not token owner");
        return IERC721(contractAddress).setApprovalForAll(operator, approved);
    }

    function approve20(address spender, uint256 amount, address contractAddress) public returns (bool){
        require(msg.sender == owner(), "Not token owner");
        return IERC20(contractAddress).approve(spender, amount);
    }

    function transferFrom20(address from, address to, uint256 amount, address contractAddress) public returns (bool){
        require(msg.sender == owner(), "Not token owner");
        return IERC20(contractAddress).transferFrom(from, to, amount);
    }

    function transfer20(address to, uint256 amount, address contractAddress) public returns (bool){
        require(msg.sender == owner(), "Not token owner");
        return IERC20(contractAddress).transfer(to, amount);
    }


    function callFunction(address targetContract,  bytes memory _callingData) public {
    // bytes memory data = abi.encodeWithSignature("setVars(uint256)", value);
    (bool success, ) = targetContract.call(_callingData);
    require(success, "Call failed");
  }




}