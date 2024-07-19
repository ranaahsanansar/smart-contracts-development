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
}



contract EXO_PublicSale is ReentrancyGuard {
    address public owner;
    ERC20 public rcToken;
    ERC20 public usdtToken;
    bool public isStart;
    uint256 public supply;
    mapping(address => uint256) public rcBalances;
    uint256 public totalRCSold;

    uint256 public constant DECIMALS = 18;
    uint256 public constant RC_MULTIPLIER = 5000000000000000; // 1 EXO = 0.005  (in wei)
    uint256 public maxTokenPerUser = 10000000 * 10**18;
    address public withdrawlAddreess;

    event buy(address indexed buyer, uint256 amount, uint256 tokens);

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can call this function"
        );
        _;
    }

    constructor(
        //  address _rcToken,
        address _usdtToken,
        uint256 _publicSupply,
        address _withdrawlAddress
    ) {
        owner = msg.sender;
        //  rcToken = ERC20(_rcToken);
        usdtToken = ERC20(_usdtToken);
        supply = _publicSupply; //15000000 * 10**18
        withdrawlAddreess = _withdrawlAddress;
        isStart = false;
    }

    function SetPublicSale(bool _status) public onlyOwner {
        isStart = _status;
    }

    function Buy(uint256 AmountETH) public nonReentrant returns (uint256) {
        //Buy function on polygon & ethereum chains
        require(isStart, "Sales has been paused!");
        uint256 amountUSDT = AmountETH / 10**12;

        require(amountUSDT > 0, "Amount must be greater than 0");
        require(amountUSDT >= 5000, "Atleast required 0.005!");

        uint256 rcAmount = (AmountETH * 10**DECIMALS) / RC_MULTIPLIER;
        

        require(rcAmount < supply, "Current Buying exceeding total Supply!");
        require(totalRCSold < supply, "Exceeding total Supply!");

        require(totalRCSold + rcAmount < supply, "Exceeding total Supply!");
        require(msg.sender != address(0), "Invalid address");

        rcBalances[msg.sender] += rcAmount;
        totalRCSold += rcAmount;

        emit buy(msg.sender, amountUSDT, rcAmount);
        return rcAmount;
    }

    function updateSupply(uint256 _supply) public onlyOwner {
        // Script runing at JS side of elysium chain that will fetch the total remaining Public supply from RC_PublicSale_Elysium
        //contract at the each emitting event of RC_PublicSale_transferred {supplyLeft Variable} and immediately update values at this contracts coipes which are depoloyed
        //on ethereum & polygon
        supply = _supply;
    }

    function withdrawUSDT() external onlyOwner {
        require(
            usdtToken.balanceOf(address(this)) > 0,
            "No USDT balance to withdraw"
        );
        usdtToken.transfer(
            withdrawlAddreess,
            usdtToken.balanceOf(address(this))
        );
    }

    function setOwner(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }
}