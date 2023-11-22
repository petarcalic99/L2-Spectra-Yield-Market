pragma solidity ^0.8.19;

import "../lib/Interfaces/starknetCore.sol";
import "../lib/Interfaces/IYT.sol";
import "../lib/Interfaces/IPrincipalToken.sol";

import "../../openzeppelin-contracts-upgradeable/contracts/interfaces/IERC20Upgradeable.sol";

contract bridge_l1 {
    
    //FIELD_PRIME is the prime number a felt can be equal to after which it overflows (P = 2^251+17*2^192+1)
    uint256 private constant FIELD_PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481;
    uint256 private constant POW251 = 3618502789000000000000000000000000000000000000000000000000000000000000000000;
    //Selector of the L2 deposit handler
    uint256 private constant DEPOSIT_UNDERLYING_SELECTOR = 550242429593000118761386392934585846287408684470658491188492705493008855;
    uint256 private constant DEPOSIT_YT_SELECTOR = 656059555830309884025984481032325730537460019592461379540739705017927077473;
    
    //L2 message identifiers
    uint256 private constant WITHDRAW_UNDERLYING = 0;
    uint256 private constant WITHDRAW_YT = 1;
    uint256 private constant WITHDRAW_YIELD = 2;

    address public owner;
    bool private isActive;
    uint256 public l2TokenBridge;


    // The StarkNet core contract.
    IStarknetCore starknetCore;
    //The YT contract.
    IYT YTContract;
    //The Underlying token.
    IERC20Upgradeable UContract;
    //The Principal Token
    IPrincipalToken PTContract; 
    

    /* EVENTS
     *****************************************************************************************************************/

    /* MODIFIERS
     *****************************************************************************************************************/
    
    //Gives acces only to the owner of the contract
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner is allowed");
        _;
    }


    //Gives acces to the function only if it has been activated after the setup.
    modifier onlyActive() {
        require(isActive, "NOT_ACTIVE_YET");
        _;
    }

     /* INITIALIZER
     *****************************************************************************************************************/

    /// @dev Set msg.sender as owner.
    constructor(IStarknetCore starknetCore_, IYT YTContract_, IERC20Upgradeable UContract_, IPrincipalToken PTContract_) {
        owner = msg.sender;
        starknetCore = starknetCore_;
        YTContract = YTContract_;
        UContract = UContract_;
        PTContract = PTContract_;
    }

    /// @dev creates a payload that will be sent to L2.
    /// @param amount amount of tokens to send, Underlying or YT.
    /// @param l2Recipient L2address to fund.
    /// @return payload the payload to send to l2.
    function depositMessagePayload(uint256 amount, uint256 l2Recipient, uint256 account) private pure returns (uint256[] memory){
        require(_isLowerThan251(amount), "Must be an amount that fits into a felt of 251bits");

        uint256[] memory payload = new uint256[](3);
        payload[0] = l2Recipient;
        payload[1] = account;
        payload[2] = amount;
        return payload;
    }

    /// @notice Deposit function that transfers funds to the L2 contract.
    /// @dev It is need to transfer U's to L2 to be able to block the funds if the user creates a buying order.
    /// @param l2ContractAddress The L2 address of the bridge the message will be sent to
    /// @param user The L2 acount of the user.
    /// @param amount The amount to bridge. 
    function depositUnderlying(uint256 l2ContractAddress, uint256 user, uint256 amount) external payable onlyActive {
        // Construct the deposit message's payload.
        uint256[] memory payload = depositMessagePayload(amount, l2ContractAddress, user);

        // Send the message to the StarkNet core contract, passing any value that was
        // passed to us as message fee.
        starknetCore.sendMessageToL2{value: msg.value}(l2ContractAddress, DEPOSIT_UNDERLYING_SELECTOR, payload);
    }

    /// @notice Deposit function that transfers funds to the L2 contract.
    /// @param l2ContractAddress The L2 address of the bridge the message will be sent to
    /// @param user The L2 acount of the user.
    /// @param amount The amount to bridge. 
    function depositYT(uint256 l2ContractAddress, uint256 user, uint256 amount) external payable onlyActive {
        // Construct the deposit message's payload.
        uint256[] memory payload = depositMessagePayload(amount, l2ContractAddress, user);

        // Send the message to the StarkNet core contract, passing any value that was
        // passed to us as message fee.
        starknetCore.sendMessageToL2{value: msg.value}(l2ContractAddress, DEPOSIT_YT_SELECTOR, payload);
    }

    /// @notice Function that is called for withdrawing the funds.
    /// @dev The function verifies the validity of the message by consuming it from the Starknet core contract.
    /// @param l2ContractAddress The L2 address of the bridge the message will be consumed from.
    /// @param user The L2 acount of the user.
    /// @param amount The amount to bridge. 
    function withdrawYT(uint256 l2ContractAddress, uint256 user, uint256 amount) external onlyActive{
        // Create the withdrawal message's payload.
        uint256[] memory payload = new uint256[](3);
        payload[0] = WITHDRAW_YT;
        payload[1] = user;
        payload[2] = amount;

        // Consume the message from the StarkNet core contract.
        // This will revert the (Ethereum) transaction if the message does not exist.
        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);

        // Update the L1 balances.
        bool succeeded = YTContract.transfer(address(uint160(user)), amount);
        require(succeeded, "operation failed");
    }

    /// @notice Function that is called for withdrawing the funds.
    /// @dev The function verifies the validity of the message by consuming it from the Starknet core contract.
    /// @param l2ContractAddress The L2 address of the bridge the message will be consumed from.
    /// @param user The L2 acount of the user.
    /// @param amount The amount to bridge.
    function withdrawUnderlying(uint256 l2ContractAddress, uint256 user, uint256 amount) external onlyActive{
        // Create the withdrawal message's payload.
        uint256[] memory payload = new uint256[](3);
        payload[0] = WITHDRAW_UNDERLYING;
        payload[1] = user;
        payload[2] = amount;

        // Consume the message from the StarkNet core contract.
        // This will revert the (Ethereum) transaction if the message does not exist.
        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);

        // Update the L1 balance.
        bool succeeded = UContract.transfer(address(uint160(user)), amount);
        require(succeeded, "operation failed");
    }

    /// @notice Function that is called for withdrawing the funds.
    /// @dev The amount is not controlable by the user, its caluclated by the L2 function.
    /// @param l2ContractAddress The L2 address of the bridge the message will be consumed from.
    /// @param user The L2 acount of the user.
    /// @param amount The amount to bridge.
    function withdrawYield(uint256 l2ContractAddress, uint256 user, uint256 amount) external onlyActive{
        // Construct the withdrawal message's payload.
        uint256[] memory payload = new uint256[](3);
        payload[0] = WITHDRAW_YIELD;
        payload[1] = user;
        payload[2] = amount;

        // Consume the message from the StarkNet core contract.
        // This will revert the (Ethereum) transaction if the message does not exist.
        starknetCore.consumeMessageFromL2(l2ContractAddress, payload);

        // Update the L1 balance.
        //PTContract.claimYieldAmountInIBT(amount, user);
    }


    /* SETTERS
     *****************************************************************************************************************/
    /// @dev Used to activate the bridge after the setup has been done.
    function Activate() private { 
        isActive = true; 
    }

    function deActivate() external onlyOwner{ 
        isActive = false; 
    }

    /// @dev The owner must set the address of the L2 bridge.
    function setL2TokenBridge(uint256 l2TokenBridge_) external onlyOwner {
        //require(isInitialized(), "CONTRACT_NOT_INITIALIZED");
        require(_isValidL2Address(l2TokenBridge_), "L2_ADDRESS_OUT_OF_RANGE");
        l2TokenBridge = l2TokenBridge_;
        Activate();
    }

    /* GETTERS
     *****************************************************************************************************************/

    /* INTERNAL FUNCTIONS
     *****************************************************************************************************************/
    /// @dev Checks if the L2 Address is a valid one.
    function _isValidL2Address(uint256 l2Address) internal pure returns (bool) {
        return (l2Address > 0 && l2Address < FIELD_PRIME);
    }

    /// @dev Checks that the amount is in the bound of an Integer of size max 251bits.
    function _isLowerThan251(uint256 amount) internal pure returns (bool) {
        return (amount <= POW251);
    }




}
