// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;


// File @openzeppelin/contracts/utils/introspection/IERC165.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)


/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File @openzeppelin/contracts/interfaces/IERC165.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)



// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)


/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// File @openzeppelin/contracts/interfaces/IERC20.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)



// File @openzeppelin/contracts/interfaces/IERC1363.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)



/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}


// File @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)


/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


// File @openzeppelin/contracts/utils/Errors.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)


/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}


// File @openzeppelin/contracts/utils/Address.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Address.sol)


/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}


// File @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/utils/SafeERC20.sol)




/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}


// File contracts/interfaces/ISwapAdapter.sol

// Original license: SPDX_License_Identifier: MIT

/// @notice Thin wrapper around whichever DEX holds Stock Token liquidity.
interface ISwapAdapter {
    /// @dev Pulls `amountIn` of `tokenIn` from msg.sender and sends at least `minOut` of `tokenOut` to `to`.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 amountOut);
}


// File contracts/adapters/UniswapV3Adapter.sol

// Original license: SPDX_License_Identifier: MIT



/// @notice Uniswap SwapRouter02 single-hop entry point.
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title UniswapV3Adapter
/// @notice Swaps through fixed Uniswap v3 pools. Which pool (fee tier) serves each pair is set at deployment.
///         No owner, no setters, holds no funds between calls.
contract UniswapV3Adapter is ISwapAdapter {
    using SafeERC20 for IERC20;

    IV3SwapRouter public immutable router;
    mapping(bytes32 => uint24) internal _fee; // pair key -> pool fee tier (500, 3000, 10000, ...)

    error NoPool(address tokenIn, address tokenOut);
    error BadConfig();

    /// @param tokensA / tokensB / fees  one entry per pool; each pool serves both directions
    constructor(address router_, address[] memory tokensA, address[] memory tokensB, uint24[] memory fees) {
        if (router_ == address(0) || tokensA.length != tokensB.length || tokensA.length != fees.length) revert BadConfig();
        router = IV3SwapRouter(router_);
        for (uint256 i; i < fees.length; ++i) {
            if (fees[i] == 0 || tokensA[i] == tokensB[i]) revert BadConfig();
            _fee[_key(tokensA[i], tokensB[i])] = fees[i];
        }
    }

    function poolFee(address a, address b) public view returns (uint24) {
        return _fee[_key(a, b)];
    }

    /// @inheritdoc ISwapAdapter
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 amountOut)
    {
        uint24 fee = poolFee(tokenIn, tokenOut);
        if (fee == 0) revert NoPool(tokenIn, tokenOut);
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(address(router), amountIn);
        amountOut = router.exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: to,
                amountIn: amountIn,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            })
        );
        IERC20(tokenIn).forceApprove(address(router), 0);
    }

    function _key(address a, address b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}


// File contracts/interfaces/AggregatorV3Interface.sol

// Original license: SPDX_License_Identifier: MIT

/// @notice Chainlink price feed interface (as documented for Robinhood Chain).
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}


// File contracts/interfaces/IValueOracle.sol

// Original license: SPDX_License_Identifier: MIT

/// @notice Values an amount of a supported asset in base-asset (USDG) units.
interface IValueOracle {
    function valueInBase(address asset, uint256 amount) external view returns (uint256);
}


// File contracts/oracles/ChainlinkOracle.sol

// Original license: SPDX_License_Identifier: MIT



/// @title ChainlinkOracle
/// @notice Values Stock Tokens in the base asset (USDG, treated as $1) using Robinhood Chain's Chainlink feeds.
///         The asset-to-feed map is fixed at deployment. No owner, no setters.
/// @dev Reverts on: unknown asset, non-positive or incomplete price, sequencer down or just restarted, stale price.
///      Rheilon accounts only call this when minting shares (deposit / join), so a stale price pauses new money
///      coming in but never blocks withdrawing or leaving.
contract ChainlinkOracle is IValueOracle {
    /// @notice After the sequencer comes back up, prices are ignored for this long.
    uint256 public constant GRACE_PERIOD = 1 hours;

    address public immutable baseAsset;
    uint8 internal immutable baseDecimals;
    AggregatorV3Interface public immutable sequencerUptimeFeed; // address(0) to skip (tests / chains without one)
    /// @notice Oldest price accepted. Stock feeds update 24/5, so this must cover a weekend.
    uint256 public immutable maxAge;

    mapping(address => AggregatorV3Interface) public feedOf;

    error UnknownAsset(address asset);
    error BadPrice(address asset);
    error StalePrice(address asset, uint256 updatedAt);
    error SequencerDown();
    error BadConfig();

    constructor(address baseAsset_, address sequencerUptimeFeed_, uint256 maxAge_, address[] memory assets, address[] memory feeds) {
        if (baseAsset_ == address(0) || assets.length != feeds.length || maxAge_ == 0) revert BadConfig();
        baseAsset = baseAsset_;
        baseDecimals = IERC20Metadata(baseAsset_).decimals();
        sequencerUptimeFeed = AggregatorV3Interface(sequencerUptimeFeed_);
        maxAge = maxAge_;
        for (uint256 i; i < assets.length; ++i) {
            if (assets[i] == address(0) || feeds[i] == address(0) || address(feedOf[assets[i]]) != address(0)) revert BadConfig();
            feedOf[assets[i]] = AggregatorV3Interface(feeds[i]);
        }
    }

    /// @inheritdoc IValueOracle
    function valueInBase(address asset, uint256 amount) external view returns (uint256) {
        if (asset == baseAsset) return amount;
        AggregatorV3Interface feed = feedOf[asset];
        if (address(feed) == address(0)) revert UnknownAsset(asset);
        _checkSequencer();

        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0 || updatedAt == 0) revert BadPrice(asset);
        if (block.timestamp - updatedAt > maxAge) revert StalePrice(asset, updatedAt);

        // amount (asset decimals) * price (feed decimals) -> base decimals
        uint256 assetDecimals = IERC20Metadata(asset).decimals();
        uint256 feedDecimals = feed.decimals();
        return (amount * uint256(answer) * (10 ** baseDecimals)) / (10 ** (assetDecimals + feedDecimals));
    }

    function _checkSequencer() internal view {
        if (address(sequencerUptimeFeed) == address(0)) return;
        (, int256 status, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
        // status 0 = up, 1 = down; startedAt = when the current status began
        if (status != 0 || startedAt == 0 || block.timestamp - startedAt <= GRACE_PERIOD) revert SequencerDown();
    }
}


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)


/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}


// File contracts/RheilonRegistry.sol

// Original license: SPDX_License_Identifier: MIT

/// @title RheilonRegistry
/// @notice An immutable configuration that crews point at: base asset, Stock Tokens, price oracle, swap route,
///         protocol fee and the beta value cap. It has no owner and no setters. A new configuration means a new
///         registry; a crew moves to it only by its own vote.
contract RheilonRegistry {
    /// @notice Hard ceiling on the protocol fee: 0.20% of each trade. Enforced here and again in every account.
    uint16 public constant MAX_FEE_BPS = 20;

    address public immutable baseAsset;
    address public immutable oracle;
    address public immutable swapAdapter;
    address public immutable treasury;
    uint16 public immutable feeBps;
    /// @notice Fee on USDG brought in when someone joins an open crew. Capped at MAX_FEE_BPS too.
    uint16 public immutable joinFeeBps;
    /// @notice Largest value (in base-asset units) a single crew may hold. 0 = no cap.
    uint256 public immutable maxCrewValue;

    mapping(address => bool) public isSupported;
    address[] internal _supported;

    error BadConfig();

    constructor(
        address baseAsset_,
        address oracle_,
        address swapAdapter_,
        address treasury_,
        uint16 feeBps_,
        uint16 joinFeeBps_,
        uint256 maxCrewValue_,
        address[] memory stockTokens
    ) {
        if (baseAsset_ == address(0) || oracle_ == address(0) || swapAdapter_ == address(0)) revert BadConfig();
        if (feeBps_ > MAX_FEE_BPS || joinFeeBps_ > MAX_FEE_BPS) revert BadConfig();
        if ((feeBps_ > 0 || joinFeeBps_ > 0) && treasury_ == address(0)) revert BadConfig();
        baseAsset = baseAsset_;
        oracle = oracle_;
        swapAdapter = swapAdapter_;
        treasury = treasury_;
        feeBps = feeBps_;
        joinFeeBps = joinFeeBps_;
        maxCrewValue = maxCrewValue_;

        isSupported[baseAsset_] = true;
        _supported.push(baseAsset_);
        for (uint256 i; i < stockTokens.length; ++i) {
            address t = stockTokens[i];
            if (t == address(0) || isSupported[t]) revert BadConfig();
            isSupported[t] = true;
            _supported.push(t);
        }
    }

    function supportedAssets() external view returns (address[] memory) {
        return _supported;
    }
}


// File contracts/RheilonAccount.sol

// Original license: SPDX_License_Identifier: MIT






/// @title RheilonAccount
/// @notice One shared account per crew. Nobody outside the crew has any power over it.
///  - Members deposit the base asset (USDG) for non-transferable shares priced at the account's current value.
///  - Trades, new members, rule changes and registry moves are proposals each member signs with their own key.
///  - A passed proposal waits out a cool-off (skipped when unanimous) so anyone who disagrees can leave first.
///  - Members can withdraw part of their share or leave entirely at any time, in kind, without a vote.
///  - Trades pay a protocol fee of at most 0.20%, taken on the USDG side. Deposits and withdrawals are free.
contract RheilonAccount is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum VoteMode {
        Heads, // one member, one vote
        Shares // votes weighted by shares
    }

    enum Kind {
        Trade, // abi.encode(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut)
        AddMember, // abi.encode(address member)
        SetRules, // abi.encode(uint16 thresholdBps, uint32 coolOff)
        MoveRegistry // abi.encode(address newRegistry)
    }

    struct Config {
        VoteMode voteMode;
        bool open; // anyone may join while seats are free
        uint8 seats; // 2..10
        uint256 minJoin; // smallest USDG amount to join an open crew
    }

    struct Proposal {
        Kind kind;
        address proposer;
        uint64 createdAt;
        uint64 expiresAt;
        uint64 readyAt; // first moment the threshold was met (0 = not met)
        bool executed;
        bool cancelled;
        bytes data;
        string note;
    }

    uint256 public constant MAX_MEMBERS = 10;
    uint256 public constant VOTE_DELAY = 3 days; // self-joined members of open crews vote after this
    uint32 public constant OPEN_MIN_COOL_OFF = 12 hours;
    uint256 public constant MAX_ASSETS = 20;
    uint256 public constant PROPOSAL_TTL = 3 days;
    uint256 public constant MAX_COOL_OFF = 2 days;
    uint16 public constant MAX_FEE_BPS = 20; // 0.20%, whatever any registry says
    uint256 internal constant VIRTUAL_SHARES = 1e6; // blunts first-deposit / donation share inflation

    RheilonRegistry public registry;
    address public immutable baseAsset;
    VoteMode public immutable voteMode;
    bool public immutable open;
    uint8 public immutable seats;
    uint256 public immutable minJoin;
    string public name;

    uint16 public thresholdBps = 6666; // two-thirds, rounded up
    uint32 public coolOff = 12 hours;

    address[] internal _members;
    mapping(address => bool) public isMember;
    mapping(address => uint256) public sharesOf;
    // Bumped every time an address joins, so approvals from an earlier membership never count again.
    mapping(address => uint256) public memberEpoch;
    // When a self-joined member may start voting (0 = founders and vote-approved members: right away).
    mapping(address => uint256) public votesFrom;
    uint256 public totalShares;

    address[] internal _assets;
    mapping(address => bool) public isHeld;

    Proposal[] internal _proposals;
    mapping(uint256 => mapping(address => uint256)) internal _approvalEpoch;

    event MemberAdded(address indexed member);
    event Joined(address indexed member, uint256 amount, uint256 fee, uint256 shares);
    event MemberLeft(address indexed member);
    event Deposited(address indexed member, uint256 amount, uint256 shares);
    event Withdrawn(address indexed member, uint256 shares, address[] assets, uint256[] amounts);
    event Proposed(uint256 indexed id, address indexed proposer, Kind kind, string note);
    event Approved(uint256 indexed id, address indexed member);
    event Unapproved(uint256 indexed id, address indexed member);
    event Ready(uint256 indexed id, uint256 executableAt);
    event Executed(uint256 indexed id);
    event Cancelled(uint256 indexed id);
    event Traded(uint256 indexed id, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee);
    event RulesChanged(uint16 thresholdBps, uint32 coolOff);
    event RegistryMoved(address registry);

    error NotMember();
    error AlreadyMember();
    error TooManyMembers();
    error TooManyAssets();
    error UnsupportedAsset(address asset);
    error NotHeld(address asset);
    error ZeroAmount();
    error NotActive();
    error ThresholdNotMet();
    error CoolOffRunning(uint256 executableAt);
    error BadRules();
    error BadRegistry();
    error OverCap(uint256 cap);
    error Slippage(uint256 received, uint256 minOut);
    error Closed();
    error Full();
    error BelowMinimum(uint256 minJoin);
    error BadConfig();

    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }

    constructor(RheilonRegistry registry_, string memory name_, address[] memory members_, Config memory cfg) {
        if (cfg.seats < 2 || cfg.seats > MAX_MEMBERS || members_.length == 0 || members_.length > cfg.seats) revert BadConfig();
        // Open crews vote by shares: extra wallets with pocket change carry no weight.
        if (cfg.open && cfg.voteMode != VoteMode.Shares) revert BadConfig();
        registry = registry_;
        baseAsset = registry_.baseAsset();
        voteMode = cfg.voteMode;
        open = cfg.open;
        seats = cfg.seats;
        minJoin = cfg.minJoin;
        name = name_;
        for (uint256 i; i < members_.length; ++i) {
            _addMember(members_[i]);
        }
        _track(baseAsset);
    }

    // ================================================================ money in / out

    /// @notice Add USDG. Shares are minted at the account's current value, so nobody gains or loses from it.
    function deposit(uint256 amount) external onlyMember nonReentrant returns (uint256 minted) {
        minted = _mint(msg.sender, amount);
        emit Deposited(msg.sender, amount, minted);
    }

    /// @notice Join an open crew by bringing at least `minJoin` USDG. A join fee (max 0.20%) goes to the protocol.
    ///         You can vote after VOTE_DELAY; you can withdraw or leave at any time.
    function join(uint256 amount) external nonReentrant returns (uint256 minted) {
        if (!open) revert Closed();
        if (isMember[msg.sender]) revert AlreadyMember();
        if (_members.length >= seats) revert Full();
        if (amount < minJoin || amount == 0) revert BelowMinimum(minJoin);

        uint256 rate = registry.joinFeeBps();
        if (rate > MAX_FEE_BPS) rate = MAX_FEE_BPS;
        uint256 fee = (amount * rate) / 10000;
        if (fee > 0) IERC20(baseAsset).safeTransferFrom(msg.sender, registry.treasury(), fee);

        _addMember(msg.sender);
        votesFrom[msg.sender] = block.timestamp + VOTE_DELAY;
        minted = _mint(msg.sender, amount - fee);
        emit Joined(msg.sender, amount, fee, minted);
    }

    function _mint(address to, uint256 amount) internal returns (uint256 minted) {
        if (amount == 0) revert ZeroAmount();
        uint256 value = accountValue();
        uint256 cap = registry.maxCrewValue();
        if (cap != 0 && value + amount > cap) revert OverCap(cap);
        minted = (amount * (totalShares + VIRTUAL_SHARES)) / (value + 1);
        if (minted == 0) revert ZeroAmount();
        IERC20(baseAsset).safeTransferFrom(to, address(this), amount);
        sharesOf[to] += minted;
        totalShares += minted;
    }

    /// @notice Take part of your share out, in kind, and stay in the crew. No vote, no fee.
    function withdraw(uint256 shares) external onlyMember nonReentrant {
        if (shares == 0 || shares > sharesOf[msg.sender]) revert ZeroAmount();
        _payOut(msg.sender, shares);
    }

    /// @notice Leave at any time, taking your whole share of every asset as it sits. No vote, no fee.
    function leave() external onlyMember nonReentrant {
        uint256 s = sharesOf[msg.sender];
        _removeMember(msg.sender);
        if (s > 0) _payOut(msg.sender, s);
        emit MemberLeft(msg.sender);
    }

    // ================================================================ proposals

    function propose(Kind kind, bytes calldata data, string calldata note) external onlyMember returns (uint256 id) {
        if (!canVote(msg.sender)) revert NotMember();
        _validate(kind, data);
        id = _proposals.length;
        _proposals.push(
            Proposal({
                kind: kind,
                proposer: msg.sender,
                createdAt: uint64(block.timestamp),
                expiresAt: uint64(block.timestamp + PROPOSAL_TTL),
                readyAt: 0,
                executed: false,
                cancelled: false,
                data: data,
                note: note
            })
        );
        emit Proposed(id, msg.sender, kind, note);
        _approve(id); // proposing counts as signing
    }

    function approve(uint256 id) external onlyMember {
        _requireActive(id);
        if (!canVote(msg.sender)) revert NotMember();
        _approve(id);
    }

    function unapprove(uint256 id) external onlyMember {
        _requireActive(id);
        _approvalEpoch[id][msg.sender] = 0;
        emit Unapproved(id, msg.sender);
        Proposal storage p = _proposals[id];
        if (p.readyAt != 0) {
            (uint256 yes, uint256 needed) = tally(id);
            if (yes < needed) p.readyAt = 0; // dropped below: the cool-off starts over next time
        }
    }

    /// @notice Starts the cool-off clock if the threshold became met some other way (e.g. a member left).
    function poke(uint256 id) external {
        _requireActive(id);
        _checkpoint(id);
    }

    function cancel(uint256 id) external {
        _requireActive(id);
        Proposal storage p = _proposals[id];
        require(msg.sender == p.proposer, "only proposer");
        p.cancelled = true;
        emit Cancelled(id);
    }

    function execute(uint256 id) external onlyMember nonReentrant {
        _requireActive(id);
        (uint256 yes, uint256 needed) = tally(id);
        if (yes < needed) revert ThresholdNotMet();

        Proposal storage p = _proposals[id];
        if (signerCount(id) < voterCount()) {
            if (p.readyAt == 0) revert CoolOffRunning(block.timestamp + coolOff); // call poke() first
            uint256 at = p.readyAt + coolOff;
            if (block.timestamp < at) revert CoolOffRunning(at);
        }

        p.executed = true;
        if (p.kind == Kind.Trade) {
            _trade(id, p.data);
        } else if (p.kind == Kind.AddMember) {
            _addMember(abi.decode(p.data, (address)));
        } else if (p.kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(p.data, (uint16, uint32));
            thresholdBps = t;
            coolOff = c;
            emit RulesChanged(t, c);
        } else {
            address r = abi.decode(p.data, (address));
            if (RheilonRegistry(r).baseAsset() != baseAsset) revert BadRegistry();
            registry = RheilonRegistry(r);
            emit RegistryMoved(r);
        }
        emit Executed(id);
    }

    // ================================================================ views

    function members() external view returns (address[] memory) {
        return _members;
    }

    function memberCount() external view returns (uint256) {
        return _members.length;
    }

    function assets() external view returns (address[] memory) {
        return _assets;
    }

    function proposalCount() external view returns (uint256) {
        return _proposals.length;
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return _proposals[id];
    }

    function hasApproved(uint256 id, address member) public view returns (bool) {
        uint256 e = memberEpoch[member];
        return canVote(member) && e != 0 && _approvalEpoch[id][member] == e;
    }

    /// @notice Members can vote right away, except self-joined members of open crews during their first days.
    function canVote(address member) public view returns (bool) {
        return isMember[member] && block.timestamp >= votesFrom[member];
    }

    function seatsLeft() external view returns (uint256) {
        return seats - _members.length;
    }

    /// @notice Number of current members who signed.
    function signerCount(uint256 id) public view returns (uint256 n) {
        for (uint256 i; i < _members.length; ++i) {
            if (hasApproved(id, _members[i])) ++n;
        }
    }

    /// @notice Members who can vote right now. Newcomers still waiting don't count in either direction.
    function voterCount() public view returns (uint256 n) {
        for (uint256 i; i < _members.length; ++i) {
            if (canVote(_members[i])) ++n;
        }
    }

    /// @return yes signed weight, needed weight (heads or shares, depending on the crew's vote mode)
    function tally(uint256 id) public view returns (uint256 yes, uint256 needed) {
        uint256 n = _members.length;
        uint256 voterShares;
        uint256 voters;
        for (uint256 i; i < n; ++i) {
            address m = _members[i];
            if (!canVote(m)) continue;
            voters += 1;
            voterShares += sharesOf[m];
        }
        bool byShares = voteMode == VoteMode.Shares && voterShares > 0;
        uint256 total = byShares ? voterShares : voters;
        for (uint256 i; i < n; ++i) {
            address m = _members[i];
            if (hasApproved(id, m)) yes += byShares ? sharesOf[m] : 1;
        }
        needed = (total * thresholdBps + 9999) / 10000;
        if (needed == 0) needed = 1;
    }

    /// @notice Total value of the account in base-asset units, priced by the crew's registry oracle.
    function accountValue() public view returns (uint256 value) {
        IValueOracle o = IValueOracle(registry.oracle());
        for (uint256 i; i < _assets.length; ++i) {
            address a = _assets[i];
            uint256 bal = IERC20(a).balanceOf(address(this));
            if (bal == 0) continue;
            value += a == baseAsset ? bal : o.valueInBase(a, bal);
        }
    }

    /// @notice Fee rate applied to trades, capped at 0.20% regardless of the registry.
    function feeBps() public view returns (uint256) {
        uint256 f = registry.feeBps();
        return f > MAX_FEE_BPS ? MAX_FEE_BPS : f;
    }

    // ================================================================ internals

    function _payOut(address to, uint256 s) internal {
        uint256 supply = totalShares;
        sharesOf[to] -= s;
        totalShares = supply - s;
        uint256 n = _assets.length;
        address[] memory paid = new address[](n);
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            address a = _assets[i];
            paid[i] = a;
            uint256 amt = (IERC20(a).balanceOf(address(this)) * s) / supply;
            amounts[i] = amt;
            if (amt > 0) IERC20(a).safeTransfer(to, amt);
        }
        emit Withdrawn(to, s, paid, amounts);
    }

    function _approve(uint256 id) internal {
        _approvalEpoch[id][msg.sender] = memberEpoch[msg.sender];
        emit Approved(id, msg.sender);
        _checkpoint(id);
    }

    function _checkpoint(uint256 id) internal {
        Proposal storage p = _proposals[id];
        if (p.readyAt != 0) return;
        (uint256 yes, uint256 needed) = tally(id);
        if (yes >= needed) {
            p.readyAt = uint64(block.timestamp);
            emit Ready(id, signerCount(id) == voterCount() ? block.timestamp : block.timestamp + coolOff);
        }
    }

    function _requireActive(uint256 id) internal view {
        Proposal storage p = _proposals[id];
        if (p.executed || p.cancelled || block.timestamp > p.expiresAt) revert NotActive();
    }

    function _validate(Kind kind, bytes calldata data) internal view {
        if (kind == Kind.Trade) {
            (address tokenIn, address tokenOut, uint256 amountIn,) = abi.decode(data, (address, address, uint256, uint256));
            if (!isHeld[tokenIn]) revert NotHeld(tokenIn); // selling a delisted asset stays possible
            if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
            if (amountIn == 0 || tokenIn == tokenOut) revert ZeroAmount();
        } else if (kind == Kind.AddMember) {
            address m = abi.decode(data, (address));
            if (m == address(0) || isMember[m]) revert AlreadyMember();
        } else if (kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(data, (uint16, uint32));
            if (t <= 5000 || t > 10000 || c > MAX_COOL_OFF) revert BadRules();
            if (open && c < OPEN_MIN_COOL_OFF) revert BadRules();
        } else {
            if (open) revert BadRegistry(); // open crews can't be moved: closes the "vote in a fake registry" route
            address r = abi.decode(data, (address));
            if (r == address(0) || r.code.length == 0 || RheilonRegistry(r).baseAsset() != baseAsset) revert BadRegistry();
        }
    }

    function _trade(uint256 id, bytes memory data) internal {
        (address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) =
            abi.decode(data, (address, address, uint256, uint256));
        if (!isHeld[tokenIn]) revert NotHeld(tokenIn);
        if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
        _track(tokenOut);

        uint256 rate = feeBps();
        address treasury = registry.treasury();
        // The fee is charged on the USDG side when there is one; otherwise on what goes in.
        bool feeOnOut = tokenOut == baseAsset && tokenIn != baseAsset;
        uint256 fee;
        uint256 swapIn = amountIn;
        if (!feeOnOut && rate > 0) {
            fee = (amountIn * rate) / 10000;
            swapIn = amountIn - fee;
            if (fee > 0) IERC20(tokenIn).safeTransfer(treasury, fee);
        }

        address adapter = registry.swapAdapter();
        uint256 before = IERC20(tokenOut).balanceOf(address(this));
        IERC20(tokenIn).forceApprove(adapter, swapIn);
        ISwapAdapter(adapter).swap(tokenIn, tokenOut, swapIn, 0, address(this));
        IERC20(tokenIn).forceApprove(adapter, 0);
        uint256 received = IERC20(tokenOut).balanceOf(address(this)) - before;

        if (feeOnOut && rate > 0) {
            fee = (received * rate) / 10000;
            received -= fee;
            if (fee > 0) IERC20(tokenOut).safeTransfer(treasury, fee);
        }
        if (received < minOut) revert Slippage(received, minOut);

        _untrackIfEmpty(tokenIn);
        emit Traded(id, tokenIn, tokenOut, amountIn, received, fee);
    }

    function _addMember(address m) internal {
        if (m == address(0) || isMember[m]) revert AlreadyMember();
        if (_members.length >= seats) revert TooManyMembers();
        isMember[m] = true;
        memberEpoch[m] += 1;
        votesFrom[m] = 0;
        _members.push(m);
        emit MemberAdded(m);
    }

    function _removeMember(address m) internal {
        isMember[m] = false;
        uint256 n = _members.length;
        for (uint256 i; i < n; ++i) {
            if (_members[i] == m) {
                _members[i] = _members[n - 1];
                _members.pop();
                return;
            }
        }
    }

    function _track(address a) internal {
        if (isHeld[a]) return;
        if (_assets.length >= MAX_ASSETS) revert TooManyAssets();
        isHeld[a] = true;
        _assets.push(a);
    }

    function _untrackIfEmpty(address a) internal {
        if (a == baseAsset || IERC20(a).balanceOf(address(this)) != 0) return;
        isHeld[a] = false;
        uint256 n = _assets.length;
        for (uint256 i; i < n; ++i) {
            if (_assets[i] == a) {
                _assets[i] = _assets[n - 1];
                _assets.pop();
                return;
            }
        }
    }
}


// File contracts/RheilonFactory.sol

// Original license: SPDX_License_Identifier: MIT


/// @title RheilonFactory
/// @notice Opens a shared account for a crew. No owner, no fees to create. The caller is always the first member.
contract RheilonFactory {
    RheilonRegistry public immutable registry;
    address[] public allAccounts;
    mapping(address => address[]) internal _accountsOf;

    event AccountCreated(address indexed account, address indexed creator, string name, bool open, uint8 seats);

    constructor(RheilonRegistry registry_) {
        registry = registry_;
    }

    /// @param open    true = anyone can join while seats are free; false = members join only by vote
    /// @param seats   crew size limit, 2..10
    /// @param minJoin smallest USDG amount a newcomer must bring to join an open crew
    function createAccount(
        string calldata name,
        address[] calldata otherMembers,
        RheilonAccount.VoteMode voteMode,
        bool open,
        uint8 seats,
        uint256 minJoin
    ) external returns (address account) {
        address[] memory members = new address[](otherMembers.length + 1);
        members[0] = msg.sender;
        for (uint256 i; i < otherMembers.length; ++i) {
            members[i + 1] = otherMembers[i];
        }
        account = address(new RheilonAccount(registry, name, members, RheilonAccount.Config(voteMode, open, seats, minJoin)));
        allAccounts.push(account);
        for (uint256 i; i < members.length; ++i) {
            _accountsOf[members[i]].push(account);
        }
        emit AccountCreated(account, msg.sender, name, open, seats);
    }

    /// @notice Accounts an address was a founding member of (later members are tracked through events).
    function accountsOf(address member) external view returns (address[] memory) {
        return _accountsOf[member];
    }

    /// @notice All open crews, for discovery pages.
    function openAccounts() external view returns (address[] memory list) {
        uint256 n;
        for (uint256 i; i < allAccounts.length; ++i) if (RheilonAccount(allAccounts[i]).open()) ++n;
        list = new address[](n);
        n = 0;
        for (uint256 i; i < allAccounts.length; ++i) if (RheilonAccount(allAccounts[i]).open()) list[n++] = allAccounts[i];
    }

    function accountCount() external view returns (uint256) {
        return allAccounts.length;
    }
}


// File contracts/RheilonLaunch.sol

// Original license: SPDX_License_Identifier: MIT




/// @title RheilonLaunch
/// @notice One deployment that sets up all of Rheilon on Robinhood Chain mainnet (chain ID 4663).
///         Every address below comes from an official source and was checked on-chain and in a mainnet-fork test:
///         tokens  - Robinhood asset registry (docs.robinhood.com/chain/contracts)
///         feeds   - Chainlink feed directory for Robinhood Chain
///         router  - Uniswap v3 SwapRouter02 (developers.uniswap.org, Robinhood Chain deployments)
///         pools   - deepest USDG pool per stock, via UniswapV3Factory.getPool
///         The only input is the treasury that receives the 0.20% fees. Nothing here has an owner.
contract RheilonLaunch {
    address public constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address public constant SWAP_ROUTER_02 = 0xCaf681a66D020601342297493863E78C959E5cb2;
    uint16 public constant TRADE_FEE_BPS = 20; // 0.20%
    uint16 public constant JOIN_FEE_BPS = 20; // 0.20%
    uint256 public constant BETA_CAP = 25_000e6; // $25,000 per crew
    uint256 public constant PRICE_MAX_AGE = 4 days; // stock feeds update 24/5

    ChainlinkOracle public immutable oracle;
    UniswapV3Adapter public immutable adapter;
    RheilonRegistry public immutable registry;
    RheilonFactory public immutable factory;

    event Launched(address oracle, address adapter, address registry, address factory, address treasury);

    constructor(address treasury) {
        require(treasury != address(0), "treasury required");
        require(block.chainid == 4663, "Robinhood Chain mainnet only");

        address[8] memory tokens = [
            0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC, // NVDA
            0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9, // AAPL
            0x322F0929c4625eD5bAd873c95208D54E1c003b2d, // TSLA
            0xe93237C50D904957Cf27E7B1133b510C669c2e74, // MSFT
            0x12f190a9F9d7D37a250758b26824B97CE941bF54, // AMZN
            0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3, // GOOGL
            0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35, // META
            0xD5f3879160bc7c32ebb4dC785F8a4F505888de68 // QQQ
        ];
        address[8] memory feeds = [
            0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15, // NVDA / USD
            0x6B22A786bAa607d76728168703a39Ea9C99f2cD0, // AAPL / USD
            0x4A1166a659A55625345e9515b32adECea5547C38, // TSLA / USD
            0x45C3C877C15E6BA2EBB19eA114Ea508d14C1Af2E, // MSFT / USD
            0xD5a1508ceD74c084eBf3cBe853e2C968fB2a651C, // AMZN / USD
            0xF6f373a037c30F0e5010d854385cA89185AE638b, // GOOGL / USD
            0x7C38C00C30BEe9378381E7B6135d7283356D71b1, // META / USD
            0x80901d846d5D7B030F26B480776EE3b29374C2ae // QQQ / USD
        ];
        uint24[8] memory poolFees = [uint24(500), 500, 3000, 3000, 3000, 500, 3000, 500];

        address[] memory t = new address[](8);
        address[] memory f = new address[](8);
        address[] memory usdgSide = new address[](8);
        uint24[] memory fees = new uint24[](8);
        for (uint256 i; i < 8; ++i) {
            t[i] = tokens[i];
            f[i] = feeds[i];
            usdgSide[i] = USDG;
            fees[i] = poolFees[i];
        }

        oracle = new ChainlinkOracle(USDG, address(0), PRICE_MAX_AGE, t, f);
        adapter = new UniswapV3Adapter(SWAP_ROUTER_02, usdgSide, t, fees);
        registry = new RheilonRegistry(USDG, address(oracle), address(adapter), treasury, TRADE_FEE_BPS, JOIN_FEE_BPS, BETA_CAP, t);
        factory = new RheilonFactory(registry);
        emit Launched(address(oracle), address(adapter), address(registry), address(factory), treasury);
    }
}
