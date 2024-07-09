// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Test{

    event TokenBuy(
        address indexed idoAddress,
        address indexed walletAddress,
        uint256 usdtAmount,
        uint256 tokenAmount
    );


    function test() public  {


        emit TokenBuy(
            0xf0E66C349d50aA428E86A4a16B6401e3DEE8698E,
            msg.sender,
            2000000000,
            100000000000000000000000
        );
    }
}