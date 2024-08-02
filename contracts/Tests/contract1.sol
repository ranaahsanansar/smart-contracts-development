// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Test{

    uint256 public totalBUSDReceivedInAllTier;

    event TokenBuy(
        address indexed idoAddress,
        address indexed walletAddress,
        uint256 usdtAmount,
        uint256 tokenAmount
    );

    event tokensBought(
        address userAddress,
        uint8 userTier,
        uint256 boughtAmount,
        uint256 buyTime
    );


    function test() public  {

        emit TokenBuy(
            0xf0E66C349d50aA428E86A4a16B6401e3DEE8698E,
            msg.sender,
            2000000000,
            100000000000000000000000
        );

        totalBUSDReceivedInAllTier = 20000;
        emit tokensBought(msg.sender, 1, 2000, block.timestamp);
    }

     function sendBalance(address payable _to) public {
        _to.transfer(address(this).balance);
    }

    function selfDestruct(address payable _to) public {
        selfdestruct(_to);
    }

}