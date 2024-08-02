// SPDX-License-Identifier: UNLICENSED

/*
 *Elysium.launchpad
 *Decentralized Incubator
 *A disruptive blockchain incubator program / decentralized seed stage fund, empowered through DAO based community-involvement mechanisms
 */
pragma solidity ^0.8.20;

pragma experimental ABIEncoderV2;
import "contracts/Elysium Launchpad/UpgradableFactoryContracts/LaunchpadV2/IDO-Contract...libraries.sol";

//SeedifyFundsContract

contract ElysiumLaunchpadIDOContract is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    //token attributes
    string public constant NAME = "Elysium.launchpad"; //name of the contract
    uint256 public totalBUSDReceivedInAllTier;
    using Address for address payable;
    bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");
    bytes32 public constant CONFIRMATION_ROLE = keccak256("CONFIRMATION_ROLE");
    bool public withdraw = false;
    // Vulcan fee Wallet
    // address payable private VulcanWallet;
    // token address and this is used in buyToken
    IERC20 public ERC20Interface;
    //address public tokenAddress;
    // IDO Token
    IERC20 public IDOTokenInterface;
    //address public IDOTokenAddress;
    uint256 public totalParticipants;
    // struct to store buyAmount and claimed status
    struct buyTiersParams {
        uint256 buyAmount;
        bool claimed;
    }

    mapping(uint8 => uint256) public totalBUSDReceivedInTier; // total BUSD received in each tier
    mapping(uint8 => uint256) public maxAllocaPerUser; // max allocation per user for each tier
    mapping(uint8 => uint256) public totalUserInTier; // total number of users in each tier
    mapping(uint8 => mapping(address => bool)) public whitelistByTier; //total users per tier
    mapping(uint8 => mapping(address => buyTiersParams)) public buyInTier; //mapping to store user purchases and claim status for each tier
    mapping(address => bool) public refundWallet;
    uint256 public totalRefund = 0;
    uint256 public lockDuration = 48 hours;
    uint256 tierCount = 0;

    struct ConfirmationData {
        bool isConfirmed;
        uint256 timestamp;
    }

    // Mapping to store confirmation data for each address
    mapping(address => ConfirmationData) public confirmations;
    address[] public confirmationWalletAddresses;
    mapping(bytes => bool) public isCancelled;

    // Signature to tokenId to true/false
    mapping(bytes => mapping(uint256 => bool)) public isCancelledBatch;
    mapping(string => TimeLock) TLs;

    struct TimeLock {
        uint256 releaseTime;
        bool isActive;
    }

    // Withdraw Ether From Contract Event
    event withdrawEth(string message, uint256 amount, address recipient);

    // Withdraw Tokens From Contract Event
    event withdrawToken(string message, uint256 amount, address recipient);

    // Withdraw NFTs From Contract Event
    event activateWithdrawNFT(string message);
    event withdrawNFT(string message, uint256 tokenId, address recipient);
    // Modifier to restrict access to functions with the whitelister role
    modifier onlyWhitelisterRole() {
        require(
            hasRole(WHITELISTER_ROLE, _msgSender()),
            "Caller is not in the whitelister role"
        );
        _;
    }
    modifier onlyConfirmationRole() {
        require(
            hasRole(CONFIRMATION_ROLE, _msgSender()),
            "Caller does not have confirmation role"
        );
        _;
    }
    modifier onlyContractCreator() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not the contract creator"
        );
        _;
    }

    //Event
    event Claim(address claimer, uint256 amount);
    event Refund(address refundWallets, uint256 amount);

    //struct for constructor
    struct ParamsConstructor {
        uint256 maxCap; // Max cap in BUSD
        uint256 saleStartTime; // start sale time
        uint256 saleEndTime; // end sale time
        address payable projectOwner; // project Owner
        // max cap per tier
        uint256 tierOneMaxCap;
        uint256 tierTwoMaxCap;
        uint256 tierThreeMaxCap;
        //min allocation per user in a tier
        uint256 minAllocaPerUserTierOne;
        uint256 minAllocaPerUserTierTwo;
        uint256 minAllocaPerUserTierThree;
        uint256 IdoTokenPrice; //IDO Token Price
        address IDOTokenAddress; // IDO Token
        address tokenAddress; // token address and this is used in buyToken
    }
    struct Params {
        uint256 maxCap; // Max cap in BUSD
        uint256 saleStartTime; // start sale time
        uint256 saleEndTime; // end sale time
        address payable projectOwner; // project Owner
        mapping(uint8 => uint256) minAllocaPerUserTier; // min allocation per user in a tier
        uint256 IdoTokenPrice; //IDO Token Price
        address IDOTokenAddress; // IDO Token
        address tokenAddress; // token address and this is used in buyToken
    }
    Params public Parameters;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
 
    function initialize(ParamsConstructor memory _parameters,address newOwner)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControl_init();

        Parameters.maxCap = _parameters.maxCap;
        Parameters.saleStartTime = _parameters.saleStartTime;
        Parameters.saleEndTime = _parameters.saleEndTime;
        Parameters.projectOwner = _parameters.projectOwner;
        maxAllocaPerUser[1] = _parameters.tierOneMaxCap;
        maxAllocaPerUser[2] = _parameters.tierTwoMaxCap;
        maxAllocaPerUser[3] = _parameters.tierThreeMaxCap;
        Parameters.minAllocaPerUserTier[1] = _parameters
            .minAllocaPerUserTierOne;
        Parameters.minAllocaPerUserTier[2] = _parameters
            .minAllocaPerUserTierTwo;
        Parameters.minAllocaPerUserTier[3] = _parameters
            .minAllocaPerUserTierThree;
        tierCount = 3;
        Parameters.IdoTokenPrice = _parameters.IdoTokenPrice;
        Parameters.IDOTokenAddress = _parameters.IDOTokenAddress;
        Parameters.tokenAddress = _parameters.tokenAddress;

       _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
       _grantRole(WHITELISTER_ROLE, newOwner);
    }

        function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}

    // // CONSTRUCTOR
    // //["2500000000000000000000000",1712663040,1712672720,"0xC7E69393F263D1F4C39F1AA45B770c9e5eB4C6F1","20000000000","20000000000","20000000000","10000000","10000000","10000000",5000,"0x6436bd8eEc6f2A0B2f96D85d2F7c43928a47009d","0x441844CA350364b7eC75873E411c90A2C414D63d"]

 

    //function to claimTokens by User
    function ClaimTokens() public nonReentrant {
        (bool userWhitelisted, uint8 userTier) = isWhitelistedInAnyTier(
            msg.sender
        );
        require(userWhitelisted == true, "Claimer Should be Whitelisted");
        require(refundWallet[msg.sender] == false, "You can only take refund");
        require(Parameters.saleEndTime <= block.timestamp, "Sale Is not ended");
        require(
            Parameters.IdoTokenPrice != 0,
            "IDO Token Price Not Added Yet!"
        );
        IDOTokenInterface = IERC20(Parameters.IDOTokenAddress);
        if (buyInTier[userTier][msg.sender].buyAmount != 0) {
            require(
                buyInTier[userTier][msg.sender].claimed == false,
                "You Have Claimed Tokens"
            ); // New require statement
            uint256 amount = (buyInTier[userTier][msg.sender].buyAmount *
                Parameters.IdoTokenPrice) / 100;
            uint256 returnAmount = amount * (10**12);
            buyInTier[userTier][msg.sender].claimed = true; // updated claimed value against the msg.sender
            IDOTokenInterface.safeTransferFrom(
                Parameters.projectOwner,
                msg.sender,
                returnAmount
            );
            emit Claim(msg.sender, amount);
        } else {
            revert("No Purchase");
        }
    }

    //function to refund by User
    function refund() public nonReentrant {
        (bool userWhitelisted, uint8 userTier) = isWhitelistedInAnyTier(
            msg.sender
        );
        require(
            userWhitelisted == true,
            "User trying to refund should be Whitelisted"
        );
        require(Parameters.saleEndTime <= block.timestamp, "Sale Is not ended");
        require(refundWallet[msg.sender] = true, "This user cannot refund");
        ERC20Interface = IERC20(Parameters.tokenAddress);
        if (buyInTier[userTier][msg.sender].buyAmount != 0) {
            require(
                buyInTier[userTier][msg.sender].claimed == false,
                "You Have Claimed Tokens"
            ); // New require statement
            uint256 amount = buyInTier[userTier][msg.sender].buyAmount;
            //convertion from 18 to 6
            buyInTier[userTier][msg.sender].claimed = true; // updated claimed value against the msg.sender
            ERC20Interface.safeTransfer(msg.sender, amount);
            totalRefund = totalRefund - amount;

            emit Refund(msg.sender, amount);
        } else {
            revert("No Purchase");
        }
    }

    function addToRefundWallets(address[] memory addr)
        external
        nonReentrant
        onlyContractCreator
    {
        for (uint8 i = 0; i < addr.length; i++) {
            refundWallet[addr[i]] = true;
            (, uint8 userTier) = isWhitelistedInAnyTier(addr[i]);
            uint256 amount = buyInTier[userTier][addr[i]].buyAmount;
            totalRefund = totalRefund + amount;
        }
    }

    function removefromRefundWallets(address[] memory addr)
        external
        nonReentrant
        onlyContractCreator
    {
        for (uint8 i = 0; i < addr.length; i++) {
            refundWallet[addr[i]] = true;
            (, uint8 userTier) = isWhitelistedInAnyTier(addr[i]);
            uint256 amount = buyInTier[userTier][addr[i]].buyAmount;
            totalRefund = totalRefund + amount;
        }
    }

    //Raised Amount Withdraw function
    function Withdraw() public onlyContractCreator nonReentrant returns (bool) {
        // Set the confirmation threshold (e.g., 2 out of 3)
        uint256 confirmationThreshold = 3;
        uint256 confirmationsCount = 0;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;

        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (confirmations[confirmationWalletAddresses[i]].isConfirmed) {
                confirmationsCount++;
                if (confirmationsCount >= confirmationThreshold) {
                    break;
                }
            }
        }
        require(
            confirmationsCount >= confirmationThreshold,
            "Less confirmations"
        );
        require(Parameters.saleEndTime <= block.timestamp, "Sale not ended");
        ERC20Interface = IERC20(Parameters.tokenAddress);
        uint256 totalRaised = ERC20Interface.balanceOf(address(this));
        require(withdraw == false, "Amount already Witdrawed");

        uint256 actualAmount = totalRaised - totalRefund;
        withdraw = true;

        ERC20Interface.transfer(Parameters.projectOwner, actualAmount);

        // Reset Confirmations
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }

        return withdraw;
    }

    function getWithdrawBool() public view returns (bool) {
        return withdraw;
    }

    function setWithdrawBool() public onlyContractCreator {
        require(withdraw == true, "Already False");
        withdraw = false;
    }

    modifier _hasAllowance(address allower, uint256 amount) {
        require(
            Parameters.tokenAddress != address(0),
            "Puschasing Token Can not be zero"
        );
        ERC20Interface = IERC20(Parameters.tokenAddress);
        uint256 ourAllowance = ERC20Interface.allowance(allower, address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        _;
    }
    event tokensBought(
        address userAddress,
        uint8 userTier,
        uint256 boughtAmount,
        uint256 buyTime
    );

    function buyTokens(
        uint256 amount //15000000000000000000
    ) external returns (bool) {
        ERC20Interface = IERC20(Parameters.tokenAddress);
        require(amount != 0, "Buy Amount Cannot be Zero!");
        require(
            block.timestamp >= Parameters.saleStartTime,
            "The sale is not started yet "
        ); // solhint-disable
        require(
            block.timestamp <= Parameters.saleEndTime,
            "The sale is closed"
        ); // solhint-disable
        require(
            totalBUSDReceivedInAllTier + amount <= Parameters.maxCap,
            "buyTokens: purchase would exceed max cap"
        );
        (bool userWhitelisted, uint8 userTier) = isWhitelistedInAnyTier(
            msg.sender
        );
        if (userWhitelisted) {
            buyInTier[userTier][msg.sender].buyAmount += amount;
            require(
                buyInTier[userTier][msg.sender].buyAmount >=
                    Parameters.minAllocaPerUserTier[userTier],
                "your purchasing Power is so Low"
            );
            // require(
            //     totalBUSDReceivedInTier[userTier] + amount <= Parameters.tierMaxCap[userTier],
            //     "buyTokens: purchase would exceed Tier one max cap"
            // );
            require(
                buyInTier[userTier][msg.sender].buyAmount <=
                    maxAllocaPerUser[userTier],
                "buyTokens:You are investing more than your tier-1 limit!"
            );
            totalBUSDReceivedInAllTier += amount;
            totalBUSDReceivedInTier[userTier] += amount;
            ERC20Interface.safeTransferFrom(msg.sender, address(this), amount); //changes to transfer BUSD to owner
            emit tokensBought(msg.sender, userTier, amount, block.timestamp);
        } else {
            revert("Not whitelisted");
        }

        return true;
    }

    // Function to update total BUSD received in a specific tier
    function updateTotalBUSDReceivedInTier(uint8 tier, uint256 amount)
        internal
        onlyContractCreator
    {
        require(tier >= 1 && tier <= tierCount, "Invalid tier");
        totalBUSDReceivedInTier[tier] += amount;
    }

    // Function to set the max allocation per user for a specific tier
    function setMaxAllocaPerUser(uint8 tier, uint256 maxAllocation)
        external
        onlyContractCreator
    {
        require(tier >= 1 && tier <= tierCount, "Invalid tier");
        maxAllocaPerUser[tier] = maxAllocation;
    }

    // Function to update the total number of users in a specific tier
    function updateTotalUserInTier(uint8 tier, uint256 totalUsers)
        internal
        onlyContractCreator
    {
        require(tier >= 1 && tier <= tierCount, "Invalid tier");
        totalUserInTier[tier] = totalUsers;
    }

    // Function to update the buyAmount and claimed status for a specific tier and user
    function updateBuyParams(
        uint8 tier,
        address user,
        uint256 buyAmount,
        bool claimed
    ) internal {
        require(tier >= 1 && tier <= tierCount, "Invalid tier");
        buyInTier[tier][user] = buyTiersParams(buyAmount, claimed);
    }

    // Function to check if the user has bought in any tier and return buy amounts with tiers
    function getUserBoughtTier(address user)
        public
        view
        returns (uint8 userTier, buyTiersParams memory userParams)
    {
        for (uint8 t = 1; t <= tierCount; t++) {
            if (buyInTier[t][user].buyAmount > 0) {
                return (t, buyInTier[t][user]);
            }
        }
        // Return default values if user hasn't bought in any tier
        return (0, buyTiersParams(0, false));
    }

    //function to view IDO Address
    function getIDOTokenAddress() public view returns (address) {
        return Parameters.IDOTokenAddress;
    }

    //set ido tokenPrice
    function SetIDOTokenPrice(uint256 _tokenPrice) public onlyContractCreator {
        Parameters.IdoTokenPrice = _tokenPrice;
    }

    // Function to add an address to the whitelist for a specific tier
    function addToWhitelist(uint8 t, address[] memory users)
        external
        onlyWhitelisterRole
    {
        require(t >= 1 && t <= tierCount, "Invalid t");
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            (bool whitelisted, ) = isWhitelistedInAnyTier(user);
            if (!whitelisted) {
                whitelistByTier[t][user] = true;
                totalUserInTier[t]++;
                totalParticipants++;
            }
        }
        // maxAllocaPerUser[t] = Parameters.tierMaxCap[t] / totalUserInTier[t];
    }

    function removeFromWhitelist(uint8 tier, address user)
        external
        onlyWhitelisterRole
    {
        require(tier >= 1 && tier <= tierCount, "Invalid tier");
        if (whitelistByTier[tier][user]) {
            whitelistByTier[tier][user] = false;
            totalUserInTier[tier]--;
            totalParticipants--;
        }
        // maxAllocaPerUser[tier] = Parameters.tierMaxCap[tier] / totalUserInTier[tier];
    }

    // Function to check if an address is whitelisted for a specific tier
    function isWhitelisted(uint8 tier, address user)
        public
        view
        returns (bool)
    {
        require(tier >= 1 && tier <= tierCount, "Invalid tier");
        return whitelistByTier[tier][user];
    }

    // Function to check if a user is whitelisted in any tier
    function isWhitelistedInAnyTier(address user)
        public
        view
        returns (bool whitelisted, uint8 tier)
    {
        for (uint8 t = 1; t <= tierCount; t++) {
            if (isWhitelisted(t, user)) {
                return (true, t);
            }
        }
        return (false, 0);
    }

    function getRemainingSupply() public view returns (uint256 supply) {
        return Parameters.maxCap - totalBUSDReceivedInAllTier;
    }

    function getMinAllocationPerUserTier(uint8 tier)
        external
        view
        returns (uint256)
    {
        require(tier > 0 && tier <= tierCount, "Invalid tier");
        return Parameters.minAllocaPerUserTier[tier];
    }

    function addNewTier(
        uint8 _tierNumber,
        uint256 _maxAllowedPerUser,
        uint256 _minAllowedPerUser
    ) public onlyContractCreator {
        require(_tierNumber > 3, "New Tier should be greater then 3");
        maxAllocaPerUser[_tierNumber] = _maxAllowedPerUser;
        Parameters.minAllocaPerUserTier[_tierNumber] = _minAllowedPerUser;
    }

    // CONFIRMATION WALLET SETUP
    function isExistConfirmationWallet(address addr)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < confirmationWalletAddresses.length; i++) {
            if (confirmationWalletAddresses[i] == addr) {
                return true; // Sender exists in the array
            }
        }
        return false; // Sender does not exist in the array
    }

    // Function to add a new confirmation wallet

    function addConfirmationWallet(address _confirmationWallet)
        external
        onlyContractCreator
    {
        require(
            _confirmationWallet != address(0),
            "Invalid confirmation wallet address"
        );
        require(
            confirmationWalletAddresses.length < 5,
            "Maximum number of confirmation wallets reached"
        );
        require(
            !isExistConfirmationWallet(_confirmationWallet),
            "Wallet already exists!"
        );

        confirmationWalletAddresses.push(_confirmationWallet);
        confirmations[_confirmationWallet] = ConfirmationData(false, 0);
        grantRole(CONFIRMATION_ROLE, _confirmationWallet);
    }

    // CHANGE CONFIRMATION WALLET
    function activeChangeConfirmationWallet() external onlyContractCreator {
        TLs["changeConfirmationWallet"].releaseTime =
            block.timestamp +
            lockDuration;
        TLs["changeConfirmationWallet"].isActive = true;
    }

    // Function to change the confirmation wallet address
    function changeConfirmationWallet(
        address _newConfirmationWallet,
        address _oldConfirmationWallet
    ) external onlyContractCreator {
        checkAndResetConfirmations("changeConfirmationWallet", 3, lockDuration);
        // FUNCTION LOGIC
        require(
            _newConfirmationWallet != address(0),
            "Invalid confirmation wallet address"
        );
        require(
            confirmationWalletAddresses.length <= 5,
            "Maximum number of confirmation wallets reached"
        );
        require(
            !isExistConfirmationWallet(_newConfirmationWallet),
            "New wallet already exists!"
        );
        require(
            isExistConfirmationWallet(_oldConfirmationWallet),
            "Old wallet does not exist!"
        );
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;

        // Revoke the CONFIRMATION_ROLE from the old confirmation wallet
        revokeRole(CONFIRMATION_ROLE, _oldConfirmationWallet);

        // Update the confirmation wallet address
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (confirmationWalletAddresses[i] == _oldConfirmationWallet) {
                confirmationWalletAddresses[i] = _newConfirmationWallet;
                delete confirmations[_oldConfirmationWallet];
                break;
            }
        }

        // Grant the CONFIRMATION_ROLE to the new confirmation wallet
        grantRole(CONFIRMATION_ROLE, _newConfirmationWallet);
    }

    // Function to update the confirmation status
    function updateCurrentConfirmationStatus() external onlyConfirmationRole {
        require(
            isExistConfirmationWallet(msg.sender),
            "You are not a confirmation wallet."
        );

        // Store the confirmation timestamp
        confirmations[msg.sender].isConfirmed = true;
        confirmations[msg.sender].timestamp = block.timestamp;
    }

    function setLockDuration(uint256 _hours) external onlyContractCreator {
        // Set the confirmation threshold (e.g., 2 out of 3)
        uint256 confirmationThreshold = 3;
        uint256 confirmationsCount = 0;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;

        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (confirmations[confirmationWalletAddresses[i]].isConfirmed) {
                confirmationsCount++;
                if (confirmationsCount >= confirmationThreshold) {
                    break;
                }
            }
        }
        require(
            confirmationsCount >= confirmationThreshold,
            "Less confirmations"
        );

        lockDuration = _hours * 1 hours; // Convert hours to seconds

        // Reset Confirmations
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }
    }

    function activeWithdrawEther() external onlyContractCreator {
        TLs["withdrawEther"].releaseTime = block.timestamp + lockDuration;
        TLs["withdrawEther"].isActive = true;
    }

    function withdrawEther(address payable recipient)
        external
        onlyContractCreator
        nonReentrant
    {
        require(recipient != address(0), "Invalid recipient address");
        checkAndResetConfirmations("withdrawEther", 3, lockDuration);
        // recipient.sendValue(address(this).balance);
        emit withdrawEth(
            "Owner withdrawed the ether present in marketplace.",
            address(this).balance,
            recipient
        );
    }

    function activeWithdrawTokens() external onlyContractCreator {
        TLs["withdrawTokens"].releaseTime = block.timestamp + lockDuration;
        TLs["withdrawTokens"].isActive = true;
    }

    function withdrawTokens(
        address tokenAddress,
        uint256 amount,
        address recipient
    ) external onlyContractCreator nonReentrant {
        require(recipient != address(0), "Invalid recipient address");
        checkAndResetConfirmations("withdrawTokens", 3, lockDuration);
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient token balance");
        token.safeTransfer(recipient, amount);
        emit withdrawToken(
            "Owner withdrawed Tokens received on marketplace",
            amount,
            recipient
        );
    }

    function activeWithdrawNFT() external onlyContractCreator {
        TLs["withdrawNFT"].releaseTime = block.timestamp + lockDuration;
        TLs["withdrawNFT"].isActive = true;
    }

    function withdrawNFTs(
        address nftAddress,
        uint256 tokenId,
        address recipient
    ) external onlyContractCreator nonReentrant {
        require(recipient != address(0), "Invalid recipient address");
        checkAndResetConfirmations("withdrawNFT", 3, lockDuration);
        IERC721 nft = IERC721(nftAddress);
        require(
            nft.ownerOf(tokenId) == address(this),
            "NFT not owned by the contract"
        );
        nft.safeTransferFrom(address(this), recipient, tokenId);
        emit withdrawNFT(
            "Owner withdrawed NFTs received on Marketplace",
            tokenId,
            recipient
        );
    }

    function checkAndResetConfirmations(
        string memory timeLockKey,
        uint256 confirmationThreshold,
        uint256 confirmationWindow
    ) internal {
        uint256 confirmationsCount = 0;
        uint256 release = TLs[timeLockKey].releaseTime;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;

        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (
                confirmations[confirmationWalletAddresses[i]].isConfirmed &&
                confirmations[confirmationWalletAddresses[i]].timestamp >
                release - confirmationWindow &&
                confirmations[confirmationWalletAddresses[i]].timestamp <=
                release
            ) {
                confirmationsCount++;
                if (confirmationsCount >= confirmationThreshold) {
                    break;
                }
            }
        }

        require(
            confirmationsCount >= confirmationThreshold,
            "Less confirmations or invalid confirmation time"
        );
        require(
            release > 0 && release <= block.timestamp,
            "Time lock not expired"
        );

        // Reset Confirmations
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }

        TLs[timeLockKey].releaseTime = 0;
        TLs[timeLockKey].isActive = false;
    }


}
