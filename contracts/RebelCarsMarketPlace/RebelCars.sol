// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.5/contracts/utils/cryptography/ECDSA.sol";


// [
// "0x9a875C57A5d99B74AB0ac6f5b8f68c6E7dB8a765",
// "0x24EE267C6247a0368b018679576325A392Af0140",
// 5,
// [2],
// [10000000000000000000],
// [1714462270],
// ["0xab55116eaef9c6ad0cdb1d8a205c53d4ab7974afee26f911655e39b3d06cf9532909448d1619c8d3a9b072042c0313196f9d0290d8475e0f7959d49fd87677ac1b",
// "0xdbae607768bdc4785bba2dafaba726effb6792ed885b71205ada87428bb303fb45b33fa4d22632f5ff6568c199a2ba34616fcd43faca411f736a6d46c7dea1f11b"],
// ["0xB1580D5634e1C7514833974767d17801717ed715","0x2b7A551Cb3D70cdD128624E37168b4E6b7C9b09F"],
// [20,30],
// "66a2"
// ]


interface ITokenBound {  
    function owner() external view returns (address);
}


// Contract for the NFT marketplace
contract AgoraMarketplace is  AccessControl { 
     // Role identifiers
    bytes32 public constant CONFIRMATION_ROLE = keccak256("CONFIRMATION_ROLE");
    bytes32 public constant SYSTEM_WALLET_ROLE = keccak256("SYSTEM_WALLET_ROLE");
    ITokenBound public tokenAccount;

    constructor(address _escrow, address defaultOwner, address _currencyAddress, address _systemWallet,uint256 _listingPercent){
       require(_escrow != address(0), "Invalid escrow address");
       require(defaultOwner != address(0), "Invalid owner address");
       require(_currencyAddress != address(0), "Invalid currency address");
       require(_systemWallet != address(0), "Invalid system wallet address");
       require(_listingPercent <= 200, "Invalid listing fee percentage");


        escrow = _escrow;
        currencyAddress= _currencyAddress;
        systemWallet=_systemWallet;
        listingPercent =_listingPercent;
        _grantRole(SYSTEM_WALLET_ROLE,_systemWallet);   
        _grantRole(DEFAULT_ADMIN_ROLE,defaultOwner);
    }

    modifier onlyContractCreator() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not the contract creator");
        _;
    }

     modifier onlyConfirmationRole() {
        require(
            hasRole(CONFIRMATION_ROLE, _msgSender()),
            "Caller does not have confirmation role"
        );
        _;
    }
    modifier onlySystemWalletRole() {
        require(
            hasRole(SYSTEM_WALLET_ROLE, _msgSender()),
            "Caller does not have cancellation role"
        );
        _;
    }
    using Address for address payable;
    using SafeERC20 for IERC20;

    // Instance of the ERC721 contract (Our NFT Contract)
    address public owner;
    address public escrow; 
    address public systemWallet; 
    address public currencyAddress; 
    uint256 public listingPercent; 
    uint256 internal immutable listingPercentageCap = 200 ;
    uint256 public priceLowerCap = 1000000000000000;

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
    mapping(string=>TimeLock) TLs;

    struct TimeLock {
    uint256 releaseTime;
    bool isActive;
    }

  
    // REENTRENCY MODIFIER
    bool locked;

    modifier noReentrancy {
    require(!locked, "Reentrancy detected");
    locked = true;
    _;
    locked = false;
    }



    // FALLBACK FUNCTION
      event Received (
        address IncomingAddress,
        address owner,
        uint256 price
    );


    struct OfferItemParams {
    address offeredBy;
    address erc721;
    uint256 tokenId;
    uint256 price;
    uint256 endTime;
    bytes[] signature;
    address[] collaboratorAddress;
    uint256[] collaboratorPercent;
    string collectionId;
    }



    struct BuyItemParams {
    address seller;
    address erc721;
    uint256 tokenToBuy;
    uint256[] tokenId; 
    uint256[] price; 
    uint256[] endTime;
    bytes[] signature; 
    address[] collaboratorAddress;
    uint256[] collaboratorPercent;
    string collectionId;
    }


    // Used for batch cancel
    struct CancelParams {
    address seller;
    address erc721;
    uint256[] tokensToCancel;
    uint256[] tokenId; 
    uint256[] price; 
    uint256[] endTime;
    bytes[] signature; 
    address[] collaboratorAddress;
    uint256[] collaboratorPercent;
    string collectionId;
    }


 
    //  Market Events
        event Bought (
        uint256 tokenId,
        address buyer,
        address seller,
        uint256 price,
        string collectionId,
        address nftContract,
        uint256 fee,
        uint256 amountToSeller
            );
 
  

        event OfferAccepted (
        uint256 tokenId,
        address acceptedBy,
        address offeredBy,
        uint256 price,
        string collectionId,
        address nftContract,
        uint256 fee,
        uint256 amountToSeller
    );
    // Change Listing Fee Event
        event changeListingFee(
        string message,
        uint256 fee
    );

    // Change Escrow Event
         event changeEscrow(
         string message,
         address escrow
    );

    // Change Escrow Event
         event changeSystemWalletAddr(
         string message,
         address signerAddress
    );

    // Change Currency Event
         event changeCurrency(
         string message,
         address currencyAddress
    );




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

    function addConfirmationWallet(address _confirmationWallet) external onlyContractCreator {
    require(_confirmationWallet != address(0), "Invalid confirmation wallet address");
    require(confirmationWalletAddresses.length < 5, "Maximum number of confirmation wallets reached");
    require(!isExistConfirmationWallet(_confirmationWallet), "Wallet already exists!");

    confirmationWalletAddresses.push(_confirmationWallet);
    confirmations[_confirmationWallet] = ConfirmationData(false, 0);
    grantRole(CONFIRMATION_ROLE, _confirmationWallet);
    }


 // CHANGE CONFIRMATION WALLET
function activeChangeConfirmationWallet() external onlyContractCreator {
    TLs["changeConfirmationWallet"].releaseTime = block.timestamp + 48 hours;
    TLs["changeConfirmationWallet"].isActive = true; 
}

// Function to change the confirmation wallet address
function changeConfirmationWallet(address _newConfirmationWallet, address _oldConfirmationWallet) external onlyContractCreator {

    checkAndResetConfirmations("changeConfirmationWallet", 3, 48 hours);
    // FUNCTION LOGIC
    require(_newConfirmationWallet != address(0), "Invalid confirmation wallet address");
    require(confirmationWalletAddresses.length <= 5, "Maximum number of confirmation wallets reached");
    require(!isExistConfirmationWallet(_newConfirmationWallet), "New wallet already exists!");
    require(isExistConfirmationWallet(_oldConfirmationWallet), "Old wallet does not exist!");
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
    require(isExistConfirmationWallet(msg.sender), "You are not a confirmation wallet.");

    // Store the confirmation timestamp
    confirmations[msg.sender].isConfirmed = true;
    confirmations[msg.sender].timestamp = block.timestamp;
}


    

    function buy(BuyItemParams memory params) external noReentrancy {
    require(isCancelledBatch[params.signature[0]][params.tokenToBuy]== false, "Token already sold");
    uint256 tokenIndex;
    
    for (uint256 i = 0; i < params.tokenId.length; i++) {
        if(params.tokenToBuy == params.tokenId[i] ){
            tokenIndex= i;
        }
    }
    require(block.timestamp <= params.endTime[tokenIndex], "Listing time has expired");
    require(params.seller != msg.sender, "Owner cannot buy his own NFT");

    bytes32 dataHash = getHashStruct(params.seller, params.erc721, params.tokenId, params.price, params.endTime, params.collaboratorAddress, params.collaboratorPercent, params.collectionId);
    bytes32 domainSeparator = geteip712DomainHash();
    bytes32 typedDataHash = generateTypedDataHash(domainSeparator, dataHash);
    require(myFunction(typedDataHash, params.signature[0]) == params.seller, "Seller signature not Verified");
    require(myFunction(typedDataHash, params.signature[1]) == systemWallet, "System signature not Verified");
    
  
       uint256 fee;
       uint256 amountToSeller;
       require(IERC721(params.erc721).ownerOf(params.tokenToBuy) == params.seller, "Seller is not the owner of this NFT");

        (fee,amountToSeller) = transferMoney(params.seller, params.price[tokenIndex], currencyAddress, params.collaboratorAddress, params.collaboratorPercent);

        IERC721(params.erc721).safeTransferFrom(params.seller, msg.sender, params.tokenToBuy);
        // Mark the token as sold
        isCancelledBatch[params.signature[0]][params.tokenToBuy] = true;
    

      emit Bought(
        params.tokenToBuy,
        msg.sender,
        params.seller,
        params.price[tokenIndex],
        params.collectionId,
        params.erc721,
        fee,
        amountToSeller
    );
}


    function buySpareParts(BuyItemParams memory params) external noReentrancy {
        require(params.tokenToBuy != 2 , "Rever");
    // require(isCancelledBatch[params.signature[0]][params.tokenToBuy]== false, "Token already sold");
    // uint256 tokenIndex;
    
    // for (uint256 i = 0; i < params.tokenId.length; i++) {
    //     if(params.tokenToBuy == params.tokenId[i] ){
    //         tokenIndex= i;
    //     }
    // }
    // require(block.timestamp <= params.endTime[tokenIndex], "Listing time has expired");
    // require(params.seller != msg.sender, "Owner cannot buy his own NFT");

    // bytes32 dataHash = getHashStruct(params.seller, params.erc721, params.tokenId, params.price, params.endTime, params.collaboratorAddress, params.collaboratorPercent, params.collectionId);
    // bytes32 domainSeparator = geteip712DomainHash();
    // bytes32 typedDataHash = generateTypedDataHash(domainSeparator, dataHash);
    // tokenAccount = ITokenBound(IERC721(params.erc721).ownerOf(params.tokenToBuy));
    // require(myFunction(typedDataHash, params.signature[0]) == tokenAccount.owner(), "Seller signature not Verified");
    // require(myFunction(typedDataHash, params.signature[1]) == systemWallet, "System signature not Verified");
    //    uint256 fee;
    //    uint256 amountToSeller;
    //    require(tokenAccount.owner() == params.seller, "Seller is not the owner of this NFT");

    //     (fee,amountToSeller) = transferMoney(params.seller, params.price[tokenIndex], currencyAddress, params.collaboratorAddress, params.collaboratorPercent);

    //     IERC721(params.erc721).safeTransferFrom(IERC721(params.erc721).ownerOf(params.tokenToBuy), msg.sender, params.tokenToBuy);
    //     // Mark the token as sold
    //     isCancelledBatch[params.signature[0]][params.tokenToBuy] = true;
    

    //   emit Bought(
    //     params.tokenToBuy,
    //     msg.sender,
    //     params.seller,
    //     params.price[tokenIndex],
    //     params.collectionId,
    //     params.erc721,
    //     fee,
    //     amountToSeller
    // );
    
}


  
        function acceptOffer(
        OfferItemParams memory params
    ) 
        external noReentrancy {

        require(isCancelled[params.signature[0]]== false, "This offer is expired");
        require(block.timestamp <= params.endTime,"This offer is expired");
          require(IERC721(params.erc721).ownerOf(params.tokenId)== msg.sender,
            "You cannot accept this offer as you are not the owner of this NFT."
        );

        bytes32 dataHash = gethashStructOffer(params.offeredBy,params.erc721,params.tokenId,params.price,params.endTime,params.collaboratorAddress,params.collaboratorPercent,params.collectionId);
        bytes32 domainSeparator = geteip712DomainHash();
        bytes32 typedDataHash = generateTypedDataHash(domainSeparator, dataHash);
        require(myFunction(typedDataHash, params.signature[0]) == params.offeredBy,"Offerer signature not Verified");
        require(myFunction(typedDataHash, params.signature[1]) == systemWallet,"System signature not Verified");
        
        uint256 fee;
        uint256 amountToSeller;

        (fee,amountToSeller)=transfers(params.offeredBy,params.price,currencyAddress,params.collaboratorAddress,params.collaboratorPercent);
      
        IERC721(params.erc721).safeTransferFrom(msg.sender,params.offeredBy,params.tokenId);
        
        isCancelled[params.signature[0]]= true;
        
        emit OfferAccepted(
        params.tokenId,
        msg.sender,
        params.offeredBy,
        params.price,
        params.collectionId,
        params.erc721,
        fee,
        amountToSeller
        );

    }

  function getOwnerFromSparePart(address erc721,uint256 tokenId)public view returns(address){   
    ITokenBound tokenAccountt;
    tokenAccountt = ITokenBound(IERC721(erc721).ownerOf(tokenId));
    return tokenAccountt.owner();
  }



function transferMoney(
    address seller,
    uint256 price,
    address erc20,
    address[] memory collaboratorAddress,
    uint256[] memory collaboratorPercent
) private returns (uint256, uint256) {

    require(price >= priceLowerCap,"Price should be greater or equal to 0.01 PYR.");

    uint256 fee = (price * listingPercent) / 1000;
    uint256 totalColab = 0;

    // Transfer to collaborators
    for (uint256 i = 0; i < collaboratorAddress.length; i++) {
        // Calculate collaborator amount based on percentage
        uint256 collaboratorAmount = ((price * collaboratorPercent[i]) / 100)/10;

        totalColab = totalColab + collaboratorAmount;

        IERC20(erc20).safeTransferFrom(
            msg.sender,
            collaboratorAddress[i],
            collaboratorAmount
        );
    }

    // Transfer to seller
    IERC20(erc20).safeTransferFrom(
        msg.sender,
        seller,
        price - fee - totalColab
    );

    // Listing fee from buyer to escrow
    IERC20(erc20).safeTransferFrom(
        msg.sender,
        escrow,
        fee
    );

    return (fee, price - fee - totalColab);
}


        function transfers ( address offeredBy,uint256 price, address erc20 ,  address[] memory collaboratorAddress,
        uint256[] memory collaboratorPercent)
        private returns (uint256,uint256)
    {   
        require(price >= priceLowerCap,"Price should be greater or equal to 0.01 PYR.");
        uint256 fee = ((price*listingPercent)/1000);    
        
          uint256 totalColab = 0;

        for (uint256 i = 0; i < collaboratorAddress.length; i++) {
        // Calculate collaborator amount based on percentage
        uint256 collaboratorAmount = ((price * collaboratorPercent[i]) / 100)/10;

        totalColab = totalColab + collaboratorAmount;

        IERC20(erc20).safeTransferFrom(
            offeredBy,
            collaboratorAddress[i],
            collaboratorAmount
        );
    }

        // Transfer to seller
       
            IERC20(erc20).safeTransferFrom(
                offeredBy,                  
                msg.sender, // Offer Accepter
                price-fee-totalColab
            );

        // Listing fee from buyer to escrow
       
            IERC20(erc20).safeTransferFrom(
                offeredBy,  
                escrow, 
                fee
            );
        
      return (fee, price - fee - totalColab);

    } 


    function cancelBatchListing (   
         CancelParams memory params) 
        external noReentrancy
    {
        
        require(params.tokensToCancel.length <= 30, "Only the listing of 30 NFTs can be cancelled at one time.");

        bytes32 dataHash = getHashStruct(params.seller,params.erc721,params.tokenId,params.price,params.endTime,params.collaboratorAddress,params.collaboratorPercent,params.collectionId);
        bytes32 domainSeparator = geteip712DomainHash();
        bytes32 typedDataHash = generateTypedDataHash(domainSeparator, dataHash);
        require(myFunction(typedDataHash, params.signature[0]) == msg.sender,"Only the owner can cancel the listing");

        for (uint256 i= 0; i < params.tokensToCancel.length; i++) 
        {
        require(isCancelledBatch[params.signature[0]][params.tokensToCancel[i]]== false, "This listing was already cancelled");
        isCancelledBatch[params.signature[0]][params.tokensToCancel[i]] = true;
        }
     

    }


        function cancelOffer (   
         OfferItemParams memory params) 
        external noReentrancy
    {
        bytes32 dataHash = gethashStructOffer(params.offeredBy,params.erc721,params.tokenId,params.price,params.endTime,params.collaboratorAddress,params.collaboratorPercent,params.collectionId);
        bytes32 domainSeparator = geteip712DomainHash();
        bytes32 typedDataHash = generateTypedDataHash(domainSeparator, dataHash);
        require(myFunction(typedDataHash, params.signature[0]) == msg.sender,"Only the offerer can cancel this offer.");
        require(isCancelled[params.signature[0]]== false, "This offer is expired");
        isCancelled[params.signature[0]] = true;
    }

    
    // -                   ----------------------- ROLE FUNCTIONS TO CALL FROM BACKEND -----------------------

    function autoCancelBatchListing(
    CancelParams memory params) 
        external onlySystemWalletRole noReentrancy
    {
        bytes32 dataHash = getHashStruct(params.seller,params.erc721,params.tokenId,params.price,params.endTime,params.collaboratorAddress,params.collaboratorPercent,params.collectionId);
        bytes32 domainSeparator = geteip712DomainHash();
        bytes32 typedDataHash = generateTypedDataHash(domainSeparator, dataHash);
        address signer=myFunction(typedDataHash, params.signature[0]) ;
        
        for (uint256 i= 0; i < params.tokensToCancel.length; i++) 
        {
        require(signer != IERC721(params.erc721).ownerOf(params.tokensToCancel[i]),"This listing cannot be cancelled because the owner and signer are same.");
        require(isCancelledBatch[params.signature[0]][params.tokensToCancel[i]]== false, "This listing was already cancelled");
        isCancelledBatch[params.signature[0]][params.tokensToCancel[i]] = true;
        }
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
            confirmations[confirmationWalletAddresses[i]].timestamp > release - confirmationWindow &&
            confirmations[confirmationWalletAddresses[i]].timestamp <= release
        ) {
            confirmationsCount++;
            if (confirmationsCount >= confirmationThreshold) {
                break;
            }
        }
    }

    require(confirmationsCount >= confirmationThreshold, "Less confirmations or invalid confirmation time");
    require(release > 0 && release <= block.timestamp, "Time lock not expired");

   

    // Reset Confirmations
    for (uint256 i = 0; i < confirmationWalletCount; i++) {
        confirmations[confirmationWalletAddresses[i]] = ConfirmationData(false, 0);
    }

    TLs[timeLockKey].releaseTime = 0;
    TLs[timeLockKey].isActive = false;
}




  //                              -------------------- ONLY OWNER FUNCTIONS -------------------

  // CHANGE LISTING FEE
  function activeSetListingFee() external onlyContractCreator {
  TLs["setListingFee"].releaseTime = block.timestamp + 48 hours;
  TLs["setListingFee"].isActive = true; 
  }

 function setListingFee(uint256 percentage) external onlyContractCreator {
    require(percentage <= listingPercentageCap, "Listing percentage cannot be more than 20%");
    checkAndResetConfirmations("setListingFee", 3, 48 hours);
    listingPercent = percentage;
   emit changeListingFee("Owner changed the listing fee percentage.", percentage / 10);
}


// CHANGE ESCROW ADDRESS
function activeChangeFeeAddress() external onlyContractCreator {
    TLs["changeFeeAddress"].releaseTime = block.timestamp + 48 hours;
    TLs["changeFeeAddress"].isActive = true;
}

function changeFeeAddress(address _newAddress) external onlyContractCreator {
    require(_newAddress != address(0), "Invalid system wallet address");
    checkAndResetConfirmations("changeFeeAddress", 3, 48 hours);
    escrow = _newAddress;
   emit changeEscrow("Owner changed the escrow address.", _newAddress);
}



// Change System Wallet Address
function activeChangeSystemWallet() external onlyContractCreator {
    TLs["changeSystemWallet"].releaseTime = block.timestamp + 48 hours;
    TLs["changeSystemWallet"].isActive = true;

    // EMIT EVENT FOR ACTIVE changeSystemWallet
    // emit activateChangeSystemWallet("Owner is going to change the System Wallet Address");
}

function changeSystemWallet(address _newAddress) external onlyContractCreator {
    require(_newAddress != address(0), "Invalid system wallet address");
    checkAndResetConfirmations("changeSystemWallet", 3, 48 hours);
    revokeRole(SYSTEM_WALLET_ROLE, systemWallet);
    systemWallet = _newAddress;
    grantRole(SYSTEM_WALLET_ROLE, _newAddress);
    emit changeSystemWalletAddr("Owner changed the system address", _newAddress);
}


  // CHANGE CURRENCY ADDRESS

  function activeChangeCurrencyAddress() external onlyContractCreator {
  TLs["changeCurrencyAddress"].releaseTime = block.timestamp + 48 hours;
  TLs["changeCurrencyAddress"].isActive = true;
  // EMIT EVENT FOR ACTIVE changeCurrencyAddress
//   emit activateChangeCurrency("Owner is going to change the Currency to be used on Marketplace");
  }

   function changeCurrencyAddress(address _currencyAddress) external onlyContractCreator {
    require(_currencyAddress != address(0), "Invalid currency address");
    checkAndResetConfirmations("changeCurrencyAddress", 3, 48 hours);
    currencyAddress = _currencyAddress;
    emit changeCurrency("Owner changed the market currency.", _currencyAddress);
}


// Change Price Lower Cap
   function activeChangePriceLowerCap() external onlyContractCreator {
  TLs["changePriceLowerCap"].releaseTime = block.timestamp + 48 hours;
  TLs["changePriceLowerCap"].isActive = true;
  }

   function changePriceLowerCap(uint256 _priceLowerCap) external onlyContractCreator {
    require(_priceLowerCap >= 1000000000000000, "Invalid lower cap limit.");
    checkAndResetConfirmations("changePriceLowerCap", 3, 48 hours);
    priceLowerCap = _priceLowerCap;
}

//                                   ------------------ ASSET WITHDRAWAL FUNCTIONS ------------------
  
  
    // Fallback function to revert any incoming Ether, ERC20, or ERC721 transfers  so there is no need for withdrawal functions (Commented out for now)
    receive() external payable {
        revert("This contract does not accept Ether, ERC20, or ERC721 transfers");
    }


     //                                      ------- FUNCTIONS TO GENERATE HASH STRUCTS ------------

/**
 * @notice Generates the hash struct used for signature verification
 * @return The hash struct representing the listing parameters
 */ 

    function gethashStructOffer(
        address offeredBy,
        address erc721,
        uint256 tokenId,
        uint256 price,
        uint256 endTime,
        address[] memory collaboratorAddress,
        uint256[] memory collaboratorPercent,
        string memory collectionId
    ) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256('ListedItem(address offeredBy,address erc721,uint256 tokenId,uint256 price,uint256 endTime,address[] collaboratorAddress,uint256[] collaboratorPercent,string collectionId)'),
                    offeredBy,
                    erc721,
                    tokenId,
                    price,
                    endTime,
                    keccak256(abi.encodePacked(collaboratorAddress)),
                    keccak256(abi.encodePacked(collaboratorPercent)),
                    keccak256(bytes(collectionId))
                )
            );
    }


       function getHashStruct(
        address seller,
        address erc721,
        uint256[] memory tokenId,
        uint256[] memory price,
        uint256[] memory endTime,
        address[] memory collaboratorAddress,
        uint256[] memory collaboratorPercent,
        string memory collectionId
    ) public pure returns (bytes32) {

        return
            keccak256(
                abi.encode(
                    keccak256('ListedItem(address seller,address erc721,uint256[] tokenId,uint256[] price,uint256[] endTime,address[] collaboratorAddress,uint256[] collaboratorPercent,string collectionId)'),
                    seller,
                    erc721,
                    keccak256(abi.encodePacked(tokenId)),
                    keccak256(abi.encodePacked(price)),
                    keccak256(abi.encodePacked(endTime)),
                    keccak256(abi.encodePacked(collaboratorAddress)),
                    keccak256(abi.encodePacked(collaboratorPercent)),
                    keccak256(bytes(collectionId))
                )
            );
    } 


      function generateTypedDataHash(bytes32 domainSeparator, bytes32 dataHash) public pure returns (bytes32) {
        return ECDSA.toTypedDataHash(domainSeparator, dataHash);
    }





/**
 * @notice Retrieves the EIP712 domain hash for signature verification
 * @return The EIP712 domain hash
 * @dev The EIP712 domain hash is calculated based on the contract's name, version, and verifying contract address
 */
    function geteip712DomainHash () public view returns (bytes32) {
        return
        keccak256(
        abi.encode(
            keccak256(
                "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
            ),
            keccak256(bytes("Listing")),
            keccak256(bytes("1")),
            block.chainid,
            address(this)
        )
        );
    }
function myFunction(bytes32 hash, bytes memory signature) public pure returns (address) {
        return ECDSALibraryWrapper.recover(hash, signature);
    }
}
library ECDSALibraryWrapper {
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        return ECDSA.recover(hash, signature);
    }
}