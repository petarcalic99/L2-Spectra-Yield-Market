// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.17;

import "openzeppelin-contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IPrincipalToken is IERC20Upgradeable, IERC4626Upgradeable {
    /* ERRORS
     *****************************************************************************************************************/
    error PrincipalTokenExpired();
    error PrincipalTokenRateError();
    error PrincipalTokenNotExpired();
    error NetYieldZero();
    error ZeroAddressError();
    error CallerIsNotOwner();
    error CallerIsNotYtContract();
    error CallerIsNotFeeCollector();
    error RatesAtExpiryNotStored();
    error RatesAtExpiryAlreadyStored();
    error FeeMoreThanMaxValue();
    error AssetsValueLessThanMinValue();
    error AssetsValueMoreThanMaxValue();
    error SharesValueLessThanMinValue();
    error SharesValueMoreThanMaxValue();
    error TransferValueExceedsYieldBalance();

    /**
     * @notice Returns the amount of shares that the Vault would exchange for the amount of assets provided
     * @param assets the amount of assets to convert
     * @param _ptRate the rate to convert at
     * @return shares the resulting amount of shares
     */
    function convertToSharesWithRate(
        uint256 assets,
        uint256 _ptRate
    ) external view returns (uint256 shares);

    /**
     * @notice Returns the amount of assets that the Vault would exchange for the amount of shares provided
     * @param shares the amount of shares to convert
     * @param _ptRate the rate to convert at
     * @return assets the resulting amount of assets
     */
    function convertToAssetsWithRate(
        uint256 shares,
        uint256 _ptRate
    ) external view returns (uint256 assets);

    /**
     * @notice Returns the equivalent amount of IBT tokens to an amount of assets
     * @param assets the amount of assets to convert
     * @param _ibtRate the rate to convert at
     * @return the corresponding amount of ibts
     */
    function convertAssetsToIBTWithRate(
        uint256 assets,
        uint256 _ibtRate
    ) external view returns (uint256);

    /**
     * @notice Returns the equivalent amount of Assets to an amount of IBT tokens
     * @param ibtAmount the amount of ibt tokens to convert
     * @param _ibtRate the rate to convert at
     * @return the corresponding amount of assets
     */
    function convertIBTToAssetsWithRate(
        uint256 ibtAmount,
        uint256 _ibtRate
    ) external view returns (uint256);

    /**
     * @dev Returns the amount of underlying assets that the Vault would exchange for the amount of principal tokens provided
     *      Equivalent function to convertToAssets
     * @param principalAmount amount of principal to convert
     */
    function convertToUnderlying(
        uint256 principalAmount
    ) external view returns (uint256);

    /**
     * @dev Returns the amount of Principal tokens that the Vault would exchange for the amount of underlying assets
     *      Equivalent function to convertToShares
     * @param underlyingAmount amount of underlying to convert
     */
    function convertToPrincipal(
        uint256 underlyingAmount
    ) external view returns (uint256);

    /**
     * @dev Return the address of the underlying token used by the Principal
     * Token for accounting, and redeeming
     */
    function underlying() external view returns (address);

    /**
     * @dev Return the unix timestamp (uint256) at or after which Principal
     * Tokens can be redeemed for their underlying deposit
     */
    function maturity() external view returns (uint256);

    /**
     * @dev Allows the owner to redeem his PT and claim his yield after expiry
     * and send it to the receiver
     *
     * @param receiver the address to which the yield and pt redeem will be sent
     * @param owner the owner of the PT
     * @return the amount of underlying withdrawn
     */
    function withdrawAfterExpiry(
        address receiver,
        address owner
    ) external returns (uint256);

    /**
     * @dev Stores PT and IBT rates at expiry. Ideally, this function should be called
     * the day of expiry
     * @return the IBT and PT rates at expiry
     */
    function storeRatesAtExpiry() external returns (uint256, uint256);

    /**
     * @dev Returns the IBT rate at expiry
     */
    function getIBTRateAtExpiry() external view returns (uint256);

    /**
     * @dev Returns the PT rate at expiry
     */
    function getPTRateAtExpiry() external view returns (uint256);

    /**
     * @notice Claims pending tokens for both sender and receiver and sets
       correct ibt balances
     * @param _from the sender of yt tokens
     * @param _to the receiver of yt tokens
     */
    function beforeYtTransfer(address _from, address _to) external;

    /**
     * @notice Calculates and transfers the yield generated in form of ibt
     * @return returns the yield that is tranferred or will be transferred
     */
    function claimYield() external returns (uint256);

    /**
     * @notice Toggle Pause
     * @dev should only be called in extraordinary situations by the admin of the contract
     */
    function pause() external;

    /**
     * @notice Toggle UnPause
     * @dev should only be called in extraordinary situations by the admin of the contract
     */
    function unPause() external;

    /**
     * @notice Setter for the fee collector address
     * @param _feeCollector the address of the fee collector
     */
    function setFeeCollector(address _feeCollector) external;

    /**
     * @notice Setter for the new protocolFee
     * @param newProtocolFee the new fee to update
     */
    function setProtocolFee(uint256 newProtocolFee) external;

    /**
     * @notice Getter for the fee collector address
     * @return the address of the fee collector
     */
    function getFeeCollectorAddress() external view returns (address);

    /**
     * @notice Updates the yield till now for the _user address
     * @param _user the user whose yield will be updated
     * @return the yield of the user
     */
    function updateYield(address _user) external returns (uint256);

    /** @dev See {IERC4626-deposit}. */
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    /** @dev Deposits amount of assets into the pt contract and mints atleast minShares to user.
     * @param assets the amount of assets being deposited
     * @param receiver the receiver of the shares
     * @param minShares The minimum expected shares from this deposit
     * @return shares the amount of shares minted to the receiver
     */
    function deposit(
        uint256 assets,
        address receiver,
        uint256 minShares
    ) external returns (uint256);

    /** @dev Deposits amount of ibt into the pt contract and mints expected shares to users
     * @param assets the amount of assets being deposited
     * @param ptReceiver the receiver of the PT
     * @param ytReceiver the receiver of the YT
     * @return shares the amount of shares minted to the receiver
     */
    function deposit(
        uint256 assets,
        address ptReceiver,
        address ytReceiver
    ) external returns (uint256);

    /** @dev Deposits amount of ibt into the pt contract and mints expected shares to users
     * @param ibtAmount the amount of ibt being deposited
     * @param receiver the receiver of the shares
     * @return shares the amount of shares minted to the receiver
     */
    function depositWithIBT(
        uint256 ibtAmount,
        address receiver
    ) external returns (uint256 shares);

    /** @dev Deposits amount of ibt into the pt contract and mints at least minShares to users
     * @param ibtAmount the amount of ibt being deposited
     * @param receiver the receiver of the shares
     * @param minShares The minimum expected shares from this deposit
     * @return shares the amount of shares minted to the receiver
     */
    function depositWithIBT(
        uint256 ibtAmount,
        address receiver,
        uint256 minShares
    ) external returns (uint256);

    /** @dev Deposits amount of ibt into the pt contract and mints at least minShares to users
     * @param ibtAmount the amount of ibt being deposited
     * @param ptReceiver the receiver of the PT
     * @param ytReceiver the receiver of the YT
     * @return shares the amount of shares minted to the receiver
     */
    function depositWithIBT(
        uint256 ibtAmount,
        address ptReceiver,
        address ytReceiver
    ) external returns (uint256 shares);

    /** @dev Takes assets(Maximum maxAssets) and mints exactly shares to user
     * @param shares the amount of shares to be minted
     * @param receiver the receiver of the shares
     * @param maxAssets The maximum assets that can be taken from the user
     * @return assets The actual amount of assets taken by pt contract for minting the shares.
     */
    function mint(
        uint256 shares,
        address receiver,
        uint256 maxAssets
    ) external returns (uint256);

    /** @dev Burns the exact shares of users and return the assets to user
     * @param shares the amount of shares to be burnt
     * @param receiver the receiver of the assets
     * @param owner the owner of the shares
     * @param minAssets The minimum assets that should be returned to user
     * @return assets The actual amount of assets returned by pt contract for burning the shares.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 minAssets
    ) external returns (uint256);

    /** @dev Burns the shares of users and return the exact assets to user
     * @param assets the amount of exact assets to be returned
     * @param receiver the receiver of the assets
     * @param owner the owner of the shares
     * @param maxShares The maximum shares that can be burnt by the pt contract
     * @return shares The actual amount of shares burnt by pt contract for returning the assets.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxShares
    ) external returns (uint256);

    /** @dev Converts the amount of ibt to its equivalent value in assets
     * @param ibtAmount The amount of ibt to convert to assets
     */
    function convertToAssetsOfIBT(
        uint256 ibtAmount
    ) external view returns (uint256);

    /** @dev Converts the amount of assets tokens to its equivalent value in ibt
     * @param assets The amount of assets to convert to ibt
     */
    function convertToSharesOfIBT(
        uint256 assets
    ) external view returns (uint256);

    /** @dev Returns the ibt address of the pt contract
     * @return ibt the address of the ibt token
     */
    function getIBT() external returns (address ibt);

    /** @dev Returns the ibtRate at the time of calling */
    function getIBTRate() external view returns (uint256);

    /** @dev Returns the ptRate at the time of calling */
    function getPTRate() external view returns (uint256);

    /** @dev Returns value equal to 1 unit of ibt */
    function getIBTUnit() external view returns (uint256);

    /** @dev Returns value equal to 1 unit of asset */
    function getAssetUnit() external view returns (uint256);

    /** @dev Returns protocol fee that has been set for the pt contract */
    function getProtocolFee() external view returns (uint256);

    /** @dev Returns the yt address of the pt contract
     * @return yt the address of the yt token
     */
    function getYT() external returns (address yt);
}
