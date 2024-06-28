// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "contracts/Elysium Launchpad/libraries.sol";

contract IDOLaunchpadStakingContract is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    IERC20 public pyrToken= IERC20(0x6436bd8eEc6f2A0B2f96D85d2F7c43928a47009d);

    struct StakedHistory {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
    }

    struct ConfirmationData {
        bool isConfirmed;
        uint256 timestamp;
    }

    bytes32 public constant CONFIRMATION_ROLE = keccak256("CONFIRMATION_ROLE");

    mapping(uint8 => mapping(address => StakedHistory)) public usersInTier;
    mapping(address => uint8) public usersTier; // tier of user
    mapping(uint8 => uint256) public totalUsersInTier;
    mapping(uint8 => uint256) public totalStakedAmountInTier;
    mapping(string => TimeLock) public TLs;
    uint256 public ownerFunctionsDuration = 1 minutes; //48 hours;
    address[] public confirmationWalletAddresses;
    mapping(address => ConfirmationData) public confirmations;

    struct TimeLock {
        uint256 releaseTime;
        bool isActive;
    }
    uint256 public lockTime = 14 days;//14 days; // right from contract deployment
    uint256 public claimTime;
    bool public isStopped;
    mapping(uint8 => uint256) public tierStakeAmounts;
    uint256 tierCount;
    event Staked(
        address indexed user,
        uint8 tier,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    );
    event Withdrawn(address indexed user, uint8 tier, uint256 amount);
    event StakingStopped(bool status, uint256 time);
    event setOwnerFunctionDuration(uint256);
    event WalletAddressUpdated(
        address indexed oldWalletAddress,
        address indexed newWalletAddress
    );

    constructor(uint256 tierOneAmount,uint256 tierTwoAmount, uint256 tierThreeAmount) {
        // pyrToken = IERC20(0xa801b1A7846156d4C81bD188F96bfcb621517611);
        tierStakeAmounts[1] = tierOneAmount ;
        tierStakeAmounts[2] = tierTwoAmount ;
        tierStakeAmounts[3] = tierThreeAmount ;
        tierCount = 3;
        claimTime = block.timestamp + lockTime;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    modifier onlyOwnerRole() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Caller is not in the Owner role"
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

    function changeStakingStatus(bool _status) external onlyOwnerRole {
        //onlyOwner
        isStopped = _status;
        emit StakingStopped(_status, block.timestamp);
    }

    function setTierStakeAmount(uint8 tier, uint256 amount)
        external
        onlyOwnerRole
    {
        //onlyOwner
        require(tier >= 1 , "Invalid tier");
        tierStakeAmounts[tier] = amount;
        tierCount++;
    }

    function stake(uint8 tier) external nonReentrant {
        require(!isStopped, "Staking paused");
        require(block.timestamp <  claimTime,"Can't lock!");
        require(tier >= 1, "Invalid tier");
        require(usersTier[msg.sender] == 0, "User has already staked");
        require(tierStakeAmounts[tier] > 0, "Tier not available for staking");
        uint256 stakeAmount = tierStakeAmounts[tier];
        require(
            pyrToken.balanceOf(msg.sender) >= stakeAmount,
            "Insufficient balance"
        );
        // Transfer tokens to the contract
        _payMe(msg.sender, stakeAmount);
        // Record staking details
        usersInTier[tier][msg.sender] = StakedHistory({
            amount: stakeAmount,
            startTime: block.timestamp,
            endTime: claimTime //block.timestamp + lockTime
        });
        // Update total users and total staked amount in the tier
        totalUsersInTier[tier]++;
        totalStakedAmountInTier[tier] += stakeAmount;
        // Set user's tier
        usersTier[msg.sender] = tier;

        emit Staked(msg.sender, tier, stakeAmount, block.timestamp, claimTime);
    }

    function hasStaked(address user) external view returns (bool) {
        return usersTier[user] > 0;
    }



    function withdraw() external nonReentrant {
        require(usersTier[msg.sender] > 0, "User has not staked");

        uint8 tier = usersTier[msg.sender];
        StakedHistory storage userStake = usersInTier[tier][msg.sender];
        require(block.timestamp >= claimTime, "still locked!");
        // Update total users and total staked amount in the tier
        totalUsersInTier[tier]--;
        totalStakedAmountInTier[tier] -= userStake.amount;

        // Transfer tokens back to the user
        _payDirect(msg.sender, userStake.amount);

        // Clear staking details
        delete usersInTier[tier][msg.sender];
        usersTier[msg.sender] = 0;

        emit Withdrawn(msg.sender, tier, userStake.amount);
    }

    function _payMe(address payer, uint256 amount) private {
        _payTo(payer, address(this), amount);
    }

    function _payTo(
        address allower,
        address receiver,
        uint256 amount
    ) private _hasAllowance(allower, amount) {
        pyrToken.safeTransferFrom(allower, receiver, amount);
    }

    function _payDirect(address to, uint256 amount) private {
        pyrToken.safeTransfer(to, amount);
    }

    modifier _hasAllowance(address allower, uint256 amount) {
        // Make sure the allower has provided the right allowance.
        uint256 ourAllowance = pyrToken.allowance(allower, address(this));
        require(amount <= ourAllowance, "Make sure to add enough allowance");
        _;
    }

    function getTotalStakedAmount() external view returns (uint256) {
        uint256 totalStaked = 0;
        for (uint8 i = 1; i <= tierCount; i++) {
            totalStaked += totalStakedAmountInTier[i];
        }
        return totalStaked;
    }

    function activeEmergencyWithdrawERC20() external onlyOwnerRole {
        TLs["EmergencyWithdrawERC20"].releaseTime =
            block.timestamp +
            (ownerFunctionsDuration);
        TLs["EmergencyWithdrawERC20"].isActive = true;
    }

    // Function to withdraw erc20 funds from contract if any, incase of emergency
    function emergencyWithdrawERC20(address userAddress)
        external
        onlyOwnerRole
    {
        // Set the confirmation threshold (e.g., 2 out of 3)
        uint256 confirmationThreshold = 3;

        // Check if enough confirmation wallets have confirmed
        uint256 confirmationsCount;
        uint256 release = TLs["EmergencyWithdrawERC20"].releaseTime;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;

        require(
            release > 0 && release <= block.timestamp,
            "Time lock not expired"
        );
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (
                confirmations[confirmationWalletAddresses[i]].isConfirmed &&
                confirmations[confirmationWalletAddresses[i]].timestamp >
                release - (ownerFunctionsDuration) &&
                confirmations[confirmationWalletAddresses[i]].timestamp <=
                release
            ) {
                if (++confirmationsCount >= confirmationThreshold) {
                    break;
                }
            }
        }

        require(
            confirmationsCount >= confirmationThreshold,
            "Less confirmations or invalid confirmation time"
        );

        // FUNCTION LOGIC

        require(usersTier[userAddress] > 0, "User has not staked");
        uint8 tier = usersTier[userAddress];
        StakedHistory storage user = usersInTier[tier][userAddress];
        _payDirect(userAddress, user.amount);

        // Update total users and total staked amount in the tier
        totalUsersInTier[tier]--;
        totalStakedAmountInTier[tier] -= user.amount;

        // Clear staking details
        delete usersInTier[tier][userAddress];
        usersTier[userAddress] = 0;

 

        // Reset confirmations
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }

        TLs["EmergencyWithdrawERC20"].releaseTime = 0; // Reset time lock
        TLs["EmergencyWithdrawERC20"].isActive = false;
    }


    // Function to add confirmation on each time by confirmation wallet
    function updateCurrentConfirmationStatus() public onlyConfirmationRole {
        require(_msgSender() != address(0), "Invalid confirmation wallet address");
        require(
            isExistConfirmationWallet(_msgSender()),
            "You are not a confirmation wallet."
        );

    
        confirmations[msg.sender] = ConfirmationData(true, block.timestamp + 1);
     
    }

    // Function to check if the wallet address exist in confirmation list wallet or not
    function isExistConfirmationWallet(address addr)
        public
        view
        returns (bool status)
    {
        for (uint256 i = 0; i < confirmationWalletAddresses.length; i++) {
            if (confirmationWalletAddresses[i] == addr) {
                return true; // Sender exists in the array
            }
        }
        return false; // Sender does not exist in the array
    }

    // Function to add wallet address in confirmation list wallet
    function addConfirmationWallet(address _confirmationWallet)
        external
        onlyOwnerRole
    {
        require(
            _confirmationWallet != address(0),
            "Invalid confirmation wallet address"
        );
        require(
            confirmationWalletAddresses.length < 5,
            "Maximum number of confirmation wallets reached"
        );

        bool isExist = isExistConfirmationWallet(_confirmationWallet);
        require(!isExist, "Wallet already exists!");

        confirmationWalletAddresses.push(_confirmationWallet);
        confirmations[_confirmationWallet] = ConfirmationData(false, 0);
        grantRole(CONFIRMATION_ROLE, _confirmationWallet);
    }

    function activeOwnerFunctionDuration() external onlyOwnerRole {
        TLs["OwnerFunctionDuration"].releaseTime =
            block.timestamp +
            (ownerFunctionsDuration);
        TLs["OwnerFunctionDuration"].isActive = true;
    }

    function OwnerFunctionDuration(uint256 _hours) external onlyOwnerRole {
        uint256 confirmationThreshold = 3;

        // Check if enough confirmation wallets have confirmed
        uint256 confirmationsCount = 0;
        uint256 release = TLs["OwnerFunctionDuration"].releaseTime;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;
        require(
            release > 0 && release <= block.timestamp,
            "Time lock not expired"
        );
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (
                confirmations[confirmationWalletAddresses[i]].isConfirmed &&
                confirmations[confirmationWalletAddresses[i]].timestamp >
                release - (ownerFunctionsDuration) &&
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

        // Function Logic
        ownerFunctionsDuration = _hours * 1 hours;

        // Reset Confirmations and Time Lock
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }

        TLs["OwnerFunctionDuration"].releaseTime = 0;
        TLs["OwnerFunctionDuration"].isActive = false;

        emit setOwnerFunctionDuration(ownerFunctionsDuration);
    }

    function activeUpdateWalletAddress() external onlyOwnerRole {
        TLs["UpdateWalletAddress"].releaseTime =
            block.timestamp +
            (ownerFunctionsDuration);
        TLs["UpdateWalletAddress"].isActive = true;
    }

    function updateWalletAddress(
        address _oldWalletAddress,
        address _newWalletAddress
    ) external onlyOwnerRole {
        uint256 confirmationThreshold = 3;

        // Check if enough confirmation wallets have confirmed
        uint256 confirmationsCount = 0;
        uint256 release = TLs["UpdateWalletAddress"].releaseTime;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;
        require(
            release > 0 && release <= block.timestamp,
            "Time lock not expired"
        );
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (
                confirmations[confirmationWalletAddresses[i]].isConfirmed &&
                confirmations[confirmationWalletAddresses[i]].timestamp >
                release - (ownerFunctionsDuration) &&
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

        // function logic

        require(_oldWalletAddress != address(0), "Invalid old wallet address");
        require(_newWalletAddress != address(0), "Invalid new wallet address");

        bool isExist = isExistConfirmationWallet(_oldWalletAddress);
        require(isExist, "Wallet not exists!");

        for (uint256 i = 0; i < confirmationWalletAddresses.length; i++) {
            if (confirmationWalletAddresses[i] == _oldWalletAddress) {
                confirmationWalletAddresses[i] = _newWalletAddress;

                confirmations[_oldWalletAddress] = ConfirmationData(false, 0);
                confirmations[_newWalletAddress] = ConfirmationData(true, 0);

                emit WalletAddressUpdated(_oldWalletAddress, _newWalletAddress);
                return;
            }
        }

        //revert("Old wallet address not found");

        // Reset Confirmations and Time Lock
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }

        TLs["UpdateWalletAddress"].releaseTime = 0;
        TLs["UpdateWalletAddress"].isActive = false;
    }

    function activelockTime() external onlyOwnerRole {
        TLs["lockTime"].releaseTime =
            block.timestamp +
            (ownerFunctionsDuration);
        TLs["lockTime"].isActive = true;
    }

    function UpdatelockTime(uint256 _days) external onlyOwnerRole {
        uint256 confirmationThreshold = 3;

        // Check if enough confirmation wallets have confirmed
        uint256 confirmationsCount = 0;
        uint256 release = TLs["lockTime"].releaseTime;
        uint256 confirmationWalletCount = confirmationWalletAddresses.length;
        require(
            release > 0 && release <= block.timestamp,
            "Time lock not expired"
        );
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            if (
                confirmations[confirmationWalletAddresses[i]].isConfirmed &&
                confirmations[confirmationWalletAddresses[i]].timestamp >
                release - (ownerFunctionsDuration) &&
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

        // Function Logic
        lockTime = _days * 1 days;

        // Reset Confirmations and Time Lock
        for (uint256 i = 0; i < confirmationWalletCount; i++) {
            confirmations[confirmationWalletAddresses[i]] = ConfirmationData(
                false,
                0
            );
        }

        TLs["lockTime"].releaseTime = 0;
        TLs["lockTime"].isActive = false;

        emit setOwnerFunctionDuration(ownerFunctionsDuration);
    }
}