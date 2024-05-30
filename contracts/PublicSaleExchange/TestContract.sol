// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ERC20 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool success);

    function transfer(address _to, uint256 _value)
        external
        returns (bool success);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);


    function totalSupply() external view  returns (uint256) ;

}

contract EXO_PublicSale_Elysium  is ReentrancyGuard {
    address public owner;
    ERC20 public rcToken;
    ERC20 public usdtToken;
    address public dexContract;
    bool public isStart;

    
    uint256 public publicSupply;
    mapping(address => uint256) public rcBalances;
    uint256 public totalRCSold;

    uint256 public constant DECIMALS = 18;
    uint256 public constant RC_MULTIPLIER = 5000000000000000; // 1 EXO = 0.005  (in wei)
    uint256 public maxTokenPerUser = 10000000 * 10**18 ;
    address public withdrawlAddreess;


    event RC_PublicSale_transferred(address indexed receiver, uint256 tokens, uint256 supplyLeft);

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can call this function"
        );
        _;
    }

    modifier onlyDex(){
        require(msg.sender == dexContract, "Only official Exchange can call this function" );
        _;
    }

    constructor(
        address _Token,
        uint256 _supply,
        address _usdtToken,
        address _withdrawlAddress
    ) {
        owner = msg.sender;
        rcToken = ERC20(_Token);
        publicSupply = _supply;    //Supply allocated for public sale     //rcToken.totalSupply(); //15000000 * 10**18
        usdtToken = ERC20(_usdtToken);
        withdrawlAddreess = _withdrawlAddress;
        isStart = false;
    }

    function SetPublicSale(bool _status) public onlyOwner {
        isStart = _status;
    }

     function transferRC(address _user, uint256 _tokens) public onlyOwner{ 
        require(isStart,"Sales has been paused!");
        // Transfer RC in case of Polygon & Ethereum
        require(publicSupply >= _tokens,"Supply Exceed!");
        require( rcBalances[_user]+_tokens<=maxTokenPerUser,"Max supply per user Exceed!");  // will check for RC tokens purchased on  Polygon & Ethereum chain

        require(
        rcToken.transfer(_user, _tokens),
       "Failed to transfer RC"
       );

       publicSupply = publicSupply - _tokens;
       rcBalances[_user] += _tokens;    // Mantain RC tokens purchased for  Polygon & Ethereum chain
       emit RC_PublicSale_transferred(_user,_tokens, publicSupply);
     }

    
    function dexBuy(uint256 AmountETH) public nonReentrant returns(uint256) {   // Buy function for elysium chain
        require(isStart,"Sales has been paused!");
        uint256 amountUSDT = AmountETH / 10**12;

        require(amountUSDT > 0, "Amount must be greater than 0");
        require(amountUSDT >= 5000, "Atleast required 0.005!");
        
        uint256 rcAmount = (AmountETH * 10**DECIMALS) / RC_MULTIPLIER;
        

        publicSupply = publicSupply - rcAmount;
        
        rcBalances[msg.sender] += rcAmount;
        totalRCSold += rcAmount;

        emit RC_PublicSale_transferred(msg.sender,rcAmount, publicSupply);
        return rcAmount;
    }

    function withdrawUSDT() external onlyOwner {
        require(
            usdtToken.balanceOf(address(this)) > 0,
            "No USDT balance to withdraw"
        );
        usdtToken.transfer(withdrawlAddreess, usdtToken.balanceOf(address(this)));
    }
    function withdrawRC() external onlyOwner {
        require(
            rcToken.balanceOf(address(this)) > 0,
            "No RC balance to withdraw"
        );
        rcToken.transfer(withdrawlAddreess, rcToken.balanceOf(address(this)));
    }
 

    function setOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

}