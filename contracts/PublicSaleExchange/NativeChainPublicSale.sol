// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

contract NativeChainPublicSale {

    uint8 public constant USDT_DECIMALS = 6;
    

    address public withdrawlAddress;
    address public  adminAddress;
    ERC20 public usdtContract;

    struct IdoInfo {
        uint256 priceUsdt;
        uint256 totalTargetUsdt;
        uint256 currentRaisedUsdt;
        uint256 maxAllowedUsdtPerWallet;
        uint256 fromDate;
        uint256 toDate;
        bool isLive;
        uint8 TOKEN_DECIMALS;
    }


    // Ido Token Address to IdoInfo
    mapping (address => IdoInfo) public publicSalesIdos;
    mapping (address => uint256) public totalTokenSold;
    mapping (address => mapping (address => uint256 )) public totalSpendUsdtPerWallet;
    mapping (address => mapping (address => uint256)) public tokenBalance;

    // modifiers ----------------------

    modifier onlyAdmin() {
        require(msg.sender == adminAddress);
        _;
    }

    // events ---------------------

    event TokenTransfered(address indexed idoAddress, address indexed walletAddress, uint256 usdtAmount , uint256 tokenAmount );

    constructor(address _withdrawlAddress , address _adminAddress, address _usdtContractAddress)  {
        withdrawlAddress = _withdrawlAddress;
        adminAddress = _adminAddress;
        usdtContract = ERC20(_usdtContractAddress);
    }

    // private functions -------------------------
    

    // public functions --------------------------

    // TODO: Remove returns 
    function buy(address _idoTokenAddress , uint256 _amountUsdt) public  {
        // require(publicSalesIdos[_idoTokenAddress].isLive == true , "Ido is not live");
        require(_amountUsdt > 0 , "Invalid amount");
        // require(publicSalesIdos[_idoTokenAddress].toDate >= block.timestamp, "Due Date expired");
        // require(publicSalesIdos[_idoTokenAddress].fromDate <= block.timestamp, "Wait for starting date");
        require(publicSalesIdos[_idoTokenAddress].currentRaisedUsdt + _amountUsdt <= publicSalesIdos[_idoTokenAddress].totalTargetUsdt  , "Exceeding total target");
        require(totalSpendUsdtPerWallet[_idoTokenAddress][msg.sender] + _amountUsdt <= publicSalesIdos[_idoTokenAddress].maxAllowedUsdtPerWallet, "Exceeding per wallet limit");
        require(publicSalesIdos[_idoTokenAddress].priceUsdt != 0 , "This ido set to invalid price");
        // Determine the conversion factor
        uint256 conversionFactor = 10**(publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS - USDT_DECIMALS);
  
        // Calculation of tokens 
        uint256 convertedUsdtAmount = _amountUsdt * conversionFactor;
        uint256 convertedPrice = publicSalesIdos[_idoTokenAddress].priceUsdt * conversionFactor;
        uint256 calculatedTokens = (convertedUsdtAmount * 10**(publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS) ) / convertedPrice;
        
        // Updating State Variables 
        totalTokenSold[_idoTokenAddress] += calculatedTokens;
        publicSalesIdos[_idoTokenAddress].currentRaisedUsdt += _amountUsdt;
        totalSpendUsdtPerWallet[_idoTokenAddress][msg.sender] += _amountUsdt;
        tokenBalance[_idoTokenAddress][msg.sender] += calculatedTokens;

        // transfer funds 
        // ERC20 tokenContract = ERC20(_idoTokenAddress);
        // require(usdtContract.transferFrom(msg.sender, address(this), _amountUsdt) , "Unable to transfer usdt tokens");
        // require(tokenContract.transfer(msg.sender, calculatedTokens), "Failed to transfer ido tokens");

        emit TokenTransfered(_idoTokenAddress, msg.sender, _amountUsdt, calculatedTokens);
        
        // return( _amountUsdt, publicSalesIdos[_idoTokenAddress].priceUsdt ,calculatedTokens , publicSalesIdos[_idoTokenAddress]);
    }

    function updateIdoStatus(address _idoAddress, bool _status) public onlyAdmin {
        publicSalesIdos[_idoAddress].isLive = _status;
        // TODO: Add sa event here
    }

    function createPublicSaleForIdo(address _idoTokenAddress , uint256 _priceUsdt, uint256 _targetUsdt , uint256 _fromDate, uint256 _toDate, uint8 _decimals, uint256 _maxAllowed ) public onlyAdmin {
        // require(publicSalesIdos[_idoTokenAddress].toDate == 0 , "This sale is already registered");
        require(_targetUsdt != 0 
                && _priceUsdt != 0 ,
                "Invalid Aurguments");

        IdoInfo memory _idoInfo= IdoInfo( 
            _priceUsdt,
            _targetUsdt,
            0,
            _maxAllowed,
            _fromDate,
            _toDate,
            false,
            _decimals);

        publicSalesIdos[_idoTokenAddress] = _idoInfo;
        
    }

    function transferTokens(address _idoTokenAddress, uint256 usdtAmount, address _walletAddress) public  onlyAdmin {
        // require(publicSalesIdos[_idoTokenAddress].isLive == true , "Ido is not live");
        // require(publicSalesIdos[_idoTokenAddress].toDate >= block.timestamp, "Due Date expired");
        // require(publicSalesIdos[_idoTokenAddress].fromDate <= block.timestamp, "Wait for starting date");
        require(publicSalesIdos[_idoTokenAddress].currentRaisedUsdt + usdtAmount <= publicSalesIdos[_idoTokenAddress].totalTargetUsdt  , "Exceeding total target");

        uint256 conversionFactor = 10**(publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS - USDT_DECIMALS);
        uint256 convertedUsdtAmount = usdtAmount * conversionFactor;
        uint256 convertedPrice = publicSalesIdos[_idoTokenAddress].priceUsdt * conversionFactor;
        uint256 calculatedTokens = (convertedUsdtAmount * 10**(publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS) ) / convertedPrice;

        // ERC20 tokenContract = ERC20(_idoTokenAddress);
        // require(tokenContract.transfer(_walletAddress, calculatedTokens), "Failed to transfer ido tokens");

        emit TokenTransfered(_idoTokenAddress, _walletAddress, usdtAmount, calculatedTokens);

    }

    function withdrawUSDT(address _idoAddress) external onlyAdmin {
        require(
            usdtContract.balanceOf(address(this)) > 0,
            "No USDT balance to withdraw"
        );
        uint256 usdtRaisedByIdo = publicSalesIdos[_idoAddress].currentRaisedUsdt;
        usdtContract.transfer(withdrawlAddress, usdtRaisedByIdo);
    }

    function withdrawToken(address _idoAddress) external onlyAdmin {
        ERC20 idoContract = ERC20(_idoAddress);

        require(
            idoContract.balanceOf(address(this)) > 0,
            "No RC balance to withdraw"
        );
        idoContract.transfer(withdrawlAddress, idoContract.balanceOf(address(this)));
    }


    // TODO: need to add sercurity flow with three wallets 
    function setAdmin(address _newOwner) external onlyAdmin {
        adminAddress = _newOwner;
    }

    function getRemainingSupply(address _idoAddress) public view  returns (uint256){
        return publicSalesIdos[_idoAddress].totalTargetUsdt - publicSalesIdos[_idoAddress].currentRaisedUsdt;
    }

}