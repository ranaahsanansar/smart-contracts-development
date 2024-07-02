// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface USDTERC20 {
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external;

    function transfer(address to, uint256 value) external;

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

contract EthereumChainPublicSale {
    uint8 public constant USDT_DECIMALS = 6;

    address public withdrawlAddress;
    address public adminAddress;
    USDTERC20 public usdtContract;

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
    mapping(address => IdoInfo) public publicSalesIdos;
    mapping(address => uint256) public totalTokenSold;
    mapping(address => mapping(address => uint256))
        public totalSpendUsdtPerWallet;
    mapping(address => mapping(address => uint256)) public tokenBalance;

    // modifiers ----------------------

    modifier onlyAdmin() {
        require(msg.sender == adminAddress);
        _;
    }

    // events ---------------------

    event TokenBuy(
        address indexed idoAddress,
        address indexed walletAddress,
        uint256 usdtAmount,
        uint256 tokenAmount
    );

    constructor(
        address _withdrawlAddress,
        address _adminAddress,
        address _usdtContractAddress
    ) {
        withdrawlAddress = _withdrawlAddress;
        adminAddress = _adminAddress;
        usdtContract = USDTERC20(_usdtContractAddress);
    }

    // private functions -------------------------

    // public functions --------------------------

    // TODO: Remove returns
    function buy(address _idoTokenAddress, uint256 _amountUsdt) public {
        require(publicSalesIdos[_idoTokenAddress].isLive == true , "Ido is not live");
        require(_amountUsdt > 0, "Invalid amount");
        require(publicSalesIdos[_idoTokenAddress].toDate >= block.timestamp, "Due Date expired");
        require(publicSalesIdos[_idoTokenAddress].fromDate <= block.timestamp, "Wait for starting date");
        require(
            publicSalesIdos[_idoTokenAddress].currentRaisedUsdt + _amountUsdt <=
                publicSalesIdos[_idoTokenAddress].totalTargetUsdt,
            "Exceeding total target"
        );
        require(
            totalSpendUsdtPerWallet[_idoTokenAddress][msg.sender] +
                _amountUsdt <=
                publicSalesIdos[_idoTokenAddress].maxAllowedUsdtPerWallet,
            "Exceeding per wallet limit"
        );
        require(
            publicSalesIdos[_idoTokenAddress].priceUsdt != 0,
            "This ido set to invalid price"
        );

        // Determine the conversion factor
        uint256 conversionFactor = 10 **
            (publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS - USDT_DECIMALS);

        // Calculation of tokens
        uint256 convertedUsdtAmount = _amountUsdt * conversionFactor;
        uint256 convertedPrice = publicSalesIdos[_idoTokenAddress].priceUsdt *
            conversionFactor;
        uint256 calculatedTokens = (convertedUsdtAmount *
            10**(publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS)) /
            convertedPrice;

        // Updating State Variables
        totalTokenSold[_idoTokenAddress] += calculatedTokens;
        publicSalesIdos[_idoTokenAddress].currentRaisedUsdt += _amountUsdt;
        totalSpendUsdtPerWallet[_idoTokenAddress][msg.sender] += _amountUsdt;
        tokenBalance[_idoTokenAddress][msg.sender] += calculatedTokens;

        // transfer funds

        usdtContract.transferFrom(msg.sender, address(this), _amountUsdt);

        emit TokenBuy(
            _idoTokenAddress,
            msg.sender,
            _amountUsdt,
            calculatedTokens
        );

    }

    function updateIdoStatus(address _idoAddress, bool _status)
        public
        onlyAdmin
    {
        publicSalesIdos[_idoAddress].isLive = _status;
        // TODO: Add sa event here
    }

    function createPublicSaleForIdo(
        address _idoTokenAddress,
        uint256 _priceUsdt,
        uint256 _targetUsdt,
        uint256 _fromDate,
        uint256 _toDate,
        uint8 _decimals,
        uint256 _maxAllowed
    ) public onlyAdmin {
        require(publicSalesIdos[_idoTokenAddress].toDate == 0 , "This sale is already registered");
        require(_targetUsdt != 0 && _priceUsdt != 0, "Invalid Aurguments");

        IdoInfo memory _idoInfo = IdoInfo(
            _priceUsdt,
            _targetUsdt,
            0,
            _maxAllowed,
            _fromDate,
            _toDate,
            false,
            _decimals
        );

        publicSalesIdos[_idoTokenAddress] = _idoInfo;
    }

    function updateIdo(
        address _idoTokenAddress,
        uint256 _priceUsdt,
        uint256 _targetUsdt,
        uint8 _decimals,
        uint256 _maxAllowed
    ) public onlyAdmin {
        publicSalesIdos[_idoTokenAddress].priceUsdt = _priceUsdt;
        publicSalesIdos[_idoTokenAddress].totalTargetUsdt = _targetUsdt;
        publicSalesIdos[_idoTokenAddress].TOKEN_DECIMALS = _decimals;
        publicSalesIdos[_idoTokenAddress].maxAllowedUsdtPerWallet = _maxAllowed;
    }

    function deleteIdo(address _idoTokenAddress) public onlyAdmin {
        require(
            publicSalesIdos[_idoTokenAddress].currentRaisedUsdt == 0,
            "This Ido can't be deleted"
        );
        delete publicSalesIdos[_idoTokenAddress];
    }

    function withdrawAllUsdt() external onlyAdmin {
        require(
            usdtContract.balanceOf(address(this)) > 0,
            "No USDT balance to withdraw"
        );
        uint256 totalBalance = usdtContract.balanceOf(address(this));
        usdtContract.transfer(withdrawlAddress, totalBalance);
    }

    function updateDatesOfIdo(
        uint256 _startDate,
        uint256 _endDate,
        address _idoTokenAddress
    ) public onlyAdmin {
        publicSalesIdos[_idoTokenAddress].fromDate = _startDate;
        publicSalesIdos[_idoTokenAddress].toDate = _endDate;
    }

    function withdrawUSDT(address _idoAddress) external onlyAdmin {
        require(
            usdtContract.balanceOf(address(this)) > 0,
            "No USDT balance to withdraw"
        );
        uint256 usdtRaisedByIdo = publicSalesIdos[_idoAddress]
            .currentRaisedUsdt;
        usdtContract.transfer(withdrawlAddress, usdtRaisedByIdo);
    }

    function withdrawToken(address _idoAddress) external onlyAdmin {
        USDTERC20 idoContract = USDTERC20(_idoAddress);

        require(
            idoContract.balanceOf(address(this)) > 0,
            "No RC balance to withdraw"
        );
        idoContract.transfer(
            withdrawlAddress,
            idoContract.balanceOf(address(this))
        );
    }

    // TODO: need to add sercurity flow with three wallets
    function setAdmin(address _newOwner) external onlyAdmin {
        adminAddress = _newOwner;
    }

    function updateRaisedAmount(
        address _idoAddress,
        address walletAddress,
        uint256 _usdtAmount,
        uint256 _tokens
    ) public onlyAdmin {
        publicSalesIdos[_idoAddress].currentRaisedUsdt = _usdtAmount;

        totalTokenSold[_idoAddress] += _tokens;
        totalSpendUsdtPerWallet[_idoAddress][walletAddress] += _usdtAmount;
        tokenBalance[_idoAddress][walletAddress] += _tokens;
    }
}
