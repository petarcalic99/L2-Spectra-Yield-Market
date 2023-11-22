// SPDX-License-Identifier: BUSL-1.1

import "openzeppelin-contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

pragma solidity 0.8.17;

interface IYT is IERC20Upgradeable {
    error CallerIsNotPtContract();

    /**
     * @notice Initializer of the contract.
     * @param name_ The name of the yt token.
     * @param symbol_ The symbol of the yt token.
     * @param principalToken The address of the PT associated with this YT token.
     */
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address principalToken
    ) external;

    /**
    @notice returns the decimals of the yt tokens.
    */
    function decimals() external view returns (uint8);

    /** @dev Returns the address of principalToken associated with this YT. */
    function getPrincipalToken() external view returns (address);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice checks for msg.sender to be principalToken and then calls _burn of ERC20Upgradeable.
     * See {ERC20Upgradeable- _burn}.
     */
    function burnWithoutUpdate(address from, uint256 amount) external;

    /**
     * @notice checks for msg.sender to be principalToken and then calls _mint of ERC20Upgradeable.
     * See {ERC20Upgradeable- _mint}.
     */
    function mint(address to, uint256 amount) external;

    /**
     * @dev Returns the amount of tokens owned by `account` before expiry, and 0 after expiry.
     * @notice This behaviour is for UI/UX purposes only.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Returns the actual amount of tokens owned by `account` at any point in time.
     */
    function actualBalanceOf(address account) external view returns (uint256);
}
