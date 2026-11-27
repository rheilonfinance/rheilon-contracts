// Sources flattened with hardhat v2.22.17 https://hardhat.org

// SPDX-License-Identifier: MIT

// File @openzeppelin/contracts/utils/introspection/IERC165.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

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

pragma solidity ^0.8.20;


// File @openzeppelin/contracts/token/ERC20/IERC20.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

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

pragma solidity ^0.8.20;


// File @openzeppelin/contracts/interfaces/IERC1363.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;


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


// File @openzeppelin/contracts/utils/Errors.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

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

pragma solidity ^0.8.20;

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

pragma solidity ^0.8.20;



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


// File @openzeppelin/contracts/utils/ReentrancyGuard.sol@v5.1.0

// Original license: SPDX_License_Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

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


// File contracts/interfaces/ISwapAdapter.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;

/// @notice Thin wrapper around whichever DEX holds Stock Token liquidity.
interface ISwapAdapter {
    /// @dev Pulls `amountIn` of `tokenIn` from msg.sender and sends at least `minOut` of `tokenOut` to `to`.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 amountOut);
}


// File contracts/interfaces/IValueOracle.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;

/// @notice Values an amount of a supported asset in base-asset (USDG) units.
interface IValueOracle {
    function valueInBase(address asset, uint256 amount) external view returns (uint256);
}


// File contracts/RheilonRegistry.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;

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
pragma solidity 0.8.24;






/// @dev The part of ERC-8056 (scaled UI amount) that Robinhood Stock Tokens implement and the account reads.
interface IERC8056 {
    function uiMultiplier() external view returns (uint256);
    function newUIMultiplier() external view returns (uint256);
    function effectiveAt() external view returns (uint256);
}

/// @title RheilonAccount
/// @notice One shared account per crew. Nobody outside the crew has any power over it.
///  - Members deposit the base asset (USDG) for non-transferable shares priced at the account's current value.
///  - Trades, new members, rule changes and registry moves are proposals each member signs with their own key.
///  - A passed proposal waits out a cool-off (skipped when unanimous) so anyone who disagrees can leave first.
///  - Members can withdraw part of their share or leave entirely, in kind, without a vote. Money added in the last
///    hour (HOLD) stays in until the hour is up.
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
        MoveRegistry, // abi.encode(address newRegistry)
        SetJoins // abi.encode(bool open): an open crew closes (or reopens) itself to joins
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

    uint256 internal constant MAX_MEMBERS = 10;
    uint256 internal constant VOTE_DELAY = 3 days; // self-joined members of open crews vote after this
    uint32 internal constant OPEN_MIN_COOL_OFF = 12 hours;
    uint256 internal constant MAX_ASSETS = 20;
    uint256 internal constant PROPOSAL_TTL = 3 days;
    uint256 internal constant MAX_COOL_OFF = 2 days;
    /// @dev Proposals that have met the bar and are waiting out the cool-off. Every change in voting weight re-checks
    ///      them, so the number is capped to keep exits cheap.
    uint256 public constant MAX_READY = 16;
    /// @notice A trade may receive at most this much less than the oracle value of what it sold, whatever minimum
    ///         the pitch carries. Stops a trade from being run inside someone's sandwich.
    uint256 public constant MAX_TRADE_LOSS_BPS = 300; // 3%
    /// @notice Moving to another registry always waits at least this long unless every member signed.
    uint32 public constant MIN_MOVE_COOL_OFF = 12 hours;
    /// @notice New shares can't be taken out for this long. Shorter than any cool-off, so a newcomer can always leave
    ///         before a pitch made after their join runs; long enough that weight can't be borrowed for a moment.
    uint256 public constant HOLD = 1 hours;

    /// @notice Shares minted to a member within the last HOLD, and when they become free.
    mapping(address => uint256) internal heldShares;
    mapping(address => uint256) public heldUntil;


    /// @notice Assets a leaver or withdrawer was owed but could not be sent (e.g. the token was paused by its
    ///         issuer). Held apart from the crew's money and claimable with `claim` once the token moves again.
    mapping(address => mapping(address => uint256)) public owed;
    mapping(address => uint256) public owedTotal;
    uint16 public constant MAX_FEE_BPS = 20; // 0.20%, whatever any registry says
    uint256 internal constant VIRTUAL_SHARES = 1e6; // blunts first-deposit / donation share inflation

    RheilonRegistry public registry;
    address public immutable baseAsset;
    VoteMode public immutable voteMode;
    /// @notice Anyone may join while seats are free. Only a crew created open can vote to close or reopen (SetJoins).
    bool public open;
    /// @notice Created as an open crew. Its open-crew limits (cool-off floor, no registry moves) stay even while it is
    ///         closed to joins.
    bool public immutable bornOpen;
    uint8 public immutable seats;
    uint256 public immutable minJoin;
    string public name;

    uint16 public thresholdBps = 6666; // two-thirds, rounded up
    uint32 public coolOff = 12 hours;
    /// @notice When the rules (threshold, cool-off) last changed. Readiness from before it doesn't count.
    uint256 public rulesChangedAt;
    /// @notice The latest vote start of a member who has since left. Kept so a vote start stays a reset point after
    ///         its member leaves: stale readiness can't come back to life by that member walking out.
    uint256 public leftVoteStart;

    /// @dev Ids of proposals whose cool-off clock is running (readyAt != 0), re-checked on every weight change.
    uint256[] internal _ready;
    mapping(uint256 => bool) internal _inReady;

    address[] internal _members;
    mapping(address => bool) public isMember;
    mapping(address => uint256) public sharesOf;
    // Bumped every time an address joins, so approvals from an earlier membership never count again.
    mapping(address => uint256) internal memberEpoch;
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
    event ReadyReset(uint256 indexed id);
    event JoinsSet(bool open);
    event Owed(address indexed member, address indexed asset, uint256 amount);
    event Claimed(address indexed member, address indexed asset, uint256 amount);
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
    error TooManyPending();
    error OracleBound(uint256 valueOut, uint256 valueIn);
    error PartialFill(uint256 spent, uint256 expected);
    error Held(uint256 until);
    error CorporateAction(address asset);
    error ReadySetChanged();

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
        bornOpen = cfg.open;
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
    ///         You can vote after VOTE_DELAY; you can withdraw or leave once the hour on new shares (HOLD) is up.
    ///         `readySet` is `readyHash()` as you saw it: the join reverts if the set of pitches that could run on your
    ///         money has changed since, so nobody's cool-off moves for a join and you never join into a surprise.
    function join(uint256 amount, bytes32 readySet) external nonReentrant returns (uint256 minted) {
        if (!open) revert Closed();
        if (readySet != readyHash()) revert ReadySetChanged();
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
        _noCorporateActionNear();
        uint256 value = accountValue();
        uint256 cap = registry.maxCrewValue();
        if (cap != 0 && value + amount > cap) revert OverCap(cap);
        minted = (amount * (totalShares + VIRTUAL_SHARES)) / (value + 1);
        if (minted == 0) revert ZeroAmount();
        IERC20(baseAsset).safeTransferFrom(to, address(this), amount);
        sharesOf[to] += minted;
        totalShares += minted;
        heldShares[to] = block.timestamp < heldUntil[to] ? heldShares[to] + minted : minted;
        heldUntil[to] = block.timestamp + HOLD;
    }

    /// @notice Take part of your share out, in kind, and stay in the crew. No vote, no fee.
    function withdraw(uint256 shares) external onlyMember nonReentrant {
        if (shares == 0 || shares > sharesOf[msg.sender]) revert ZeroAmount();
        if (shares > freeShares(msg.sender)) revert Held(heldUntil[msg.sender]);
        uint256[] memory signed = _readySignedBy(msg.sender);
        _payOut(msg.sender, shares);
        _resetBelow(signed);
    }

    /// @notice Leave, taking your whole share of every asset as it sits. No vote, no fee. Shares minted in the last
    ///         hour (HOLD) have to wait the hour out first.
    function leave() external onlyMember nonReentrant {
        uint256 s = sharesOf[msg.sender];
        if (s != freeShares(msg.sender)) revert Held(heldUntil[msg.sender]);
        heldShares[msg.sender] = 0;
        heldUntil[msg.sender] = 0;
        uint256[] memory signed = _readySignedBy(msg.sender);
        uint256 v = votesFrom[msg.sender];
        if (v <= block.timestamp && v > leftVoteStart) leftVoteStart = v;
        _removeMember(msg.sender);
        if (s > 0) _payOut(msg.sender, s);
        emit MemberLeft(msg.sender);
        _resetBelow(signed);
    }

    /// @notice Collect an asset you were owed when you withdrew or left but that couldn't be sent at the time.
    function claim(address asset) external nonReentrant {
        uint256 amt = owed[msg.sender][asset];
        if (amt == 0) revert ZeroAmount();
        owed[msg.sender][asset] = 0;
        owedTotal[asset] -= amt;
        IERC20(asset).safeTransfer(msg.sender, amt);
        emit Claimed(msg.sender, asset, amt);
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
            if (yes < needed) {
                p.readyAt = 0; // dropped below: the cool-off starts over next time
                emit ReadyReset(id);
            }
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
        if (msg.sender != p.proposer) revert NotMember();
        p.cancelled = true;
        emit Cancelled(id);
    }

    function execute(uint256 id) external onlyMember nonReentrant {
        if (!canVote(msg.sender)) revert NotMember();
        _requireActive(id);
        (uint256 yes, uint256 needed) = tally(id);
        if (yes < needed) revert ThresholdNotMet();

        Proposal storage p = _proposals[id];
        if (!unanimous(id)) {
            uint256 wait = coolOff;
            if (p.kind == Kind.MoveRegistry && wait < MIN_MOVE_COOL_OFF) wait = MIN_MOVE_COOL_OFF;
            // not ready, or ready only from before the latest newcomer could vote: call poke() to re-check it first
            // SetJoins moves no money, so a newcomer's vote starting doesn't hold it off (a churner can't keep the door open)
            if (p.readyAt == 0 || (p.kind != Kind.SetJoins && p.readyAt < latestVoteStart())) revert CoolOffRunning(block.timestamp + wait);
            uint256 at = p.readyAt + wait;
            if (block.timestamp < at) revert CoolOffRunning(at);
        }

        p.executed = true;
        if (p.kind == Kind.Trade) {
            _trade(id, p.data);
        } else if (p.kind == Kind.AddMember) {
            _addMember(abi.decode(p.data, (address)));
        } else if (p.kind == Kind.SetJoins) {
            open = abi.decode(p.data, (bool));
            emit JoinsSet(open);
        } else if (p.kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(p.data, (uint16, uint32));
            thresholdBps = t;
            coolOff = c;
            emit RulesChanged(t, c);
            rulesChangedAt = block.timestamp;
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

    /// @notice Number of current members who signed.
    function signerCount(uint256 id) internal view returns (uint256 n) {
        for (uint256 i; i < _members.length; ++i) {
            if (hasApproved(id, _members[i])) ++n;
        }
    }

    /// @notice The latest change in who votes or how: a member gaining their vote (voted in, or a newcomer's
    ///         VOTE_DELAY ending) or new rules. Readiness from before it doesn't count until it passes again.
    function latestVoteStart() public view returns (uint256 t) {
        t = rulesChangedAt > leftVoteStart ? rulesChangedAt : leftVoteStart;
        for (uint256 i; i < _members.length; ++i) {
            uint256 v = votesFrom[_members[i]];
            if (v <= block.timestamp && v > t) t = v;
        }
    }

    /// @notice Fingerprint of the pitches that could run on a newcomer's money: every active ready proposal, by id.
    ///         `join` takes it as consent, so joining never moves anyone's cool-off and a joiner sees what's coming.
    function readyHash() public view returns (bytes32) {
        uint256 since = latestVoteStart();
        uint256[] memory ids = new uint256[](_ready.length);
        uint256 n;
        for (uint256 i; i < _ready.length; ++i) {
            Proposal storage p = _proposals[_ready[i]];
            if (p.readyAt == 0 || p.readyAt < since || p.executed || p.cancelled || block.timestamp > p.expiresAt) continue;
            uint256 id = _ready[i];
            uint256 j = n++;
            while (j > 0 && ids[j - 1] > id) {
                ids[j] = ids[j - 1];
                --j;
            }
            ids[j] = id;
        }
        assembly { mstore(ids, n) }
        return keccak256(abi.encode(ids));
    }

    /// @notice Shares a member can take out right now (everything except what they added in the last HOLD).
    function freeShares(address member) public view returns (uint256) {
        uint256 s = sharesOf[member];
        if (block.timestamp >= heldUntil[member]) return s;
        uint256 h = heldShares[member];
        return h >= s ? 0 : s - h;
    }

    /// @notice Every member signed. A newcomer who can't vote yet can't sign either, so while anyone is still waiting
    ///         nothing is unanimous and the cool-off always applies: they get time to leave before it runs.
    function unanimous(uint256 id) internal view returns (bool) {
        return signerCount(id) == _members.length;
    }

    /// @notice Members who can vote right now. Newcomers still waiting don't count towards the bar.
    function voterCount() internal view returns (uint256 n) {
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
            uint256 bal = _free(a);
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
            uint256 amt = (_free(a) * s) / supply;
            amounts[i] = amt;
            if (amt > 0 && !_trySend(a, to, amt)) {
                // one paused token must not lock everything else: keep it aside for the member to claim later
                owed[to][a] += amt;
                owedTotal[a] += amt;
                emit Owed(to, a, amt);
            }
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
        if (p.readyAt != 0 && (p.kind == Kind.SetJoins || p.readyAt >= latestVoteStart())) return;
        (uint256 yes, uint256 needed) = tally(id);
        if (yes >= needed) {
            if (!_inReady[id]) {
                _pruneReady();
                if (_ready.length >= MAX_READY) revert TooManyPending();
                _ready.push(id);
                _inReady[id] = true;
            }
            p.readyAt = uint64(block.timestamp);
            emit Ready(id, unanimous(id) ? block.timestamp : block.timestamp + coolOff);
        }
    }

    /// @dev Drops proposals that are no longer waiting (ran, cancelled, expired or reset) from the ready list.
    function _pruneReady() internal {
        uint256 i;
        while (i < _ready.length) {
            uint256 id = _ready[i];
            Proposal storage p = _proposals[id];
            if (p.readyAt == 0 || p.executed || p.cancelled || block.timestamp > p.expiresAt) {
                _inReady[id] = false;
                _ready[i] = _ready[_ready.length - 1];
                _ready.pop();
            } else {
                ++i;
            }
        }
    }

    /// @dev Waiting proposals this member has signed, read before their weight changes.
    function _readySignedBy(address m) internal returns (uint256[] memory ids) {
        _pruneReady();
        uint256 n = _ready.length;
        ids = new uint256[](n);
        uint256 k;
        for (uint256 i; i < n; ++i) if (hasApproved(_ready[i], m)) ids[k++] = _ready[i];
        assembly { mstore(ids, k) }
    }

    /// @dev After a signer's weight fell (they withdrew or left): each proposal they signed that is now below the bar
    ///      loses its readiness, so its cool-off starts over the next time it passes. Someone who never signed can't
    ///      reset a pitch this way; a deposit of theirs is weighed at `execute` instead.
    function _resetBelow(uint256[] memory ids) internal {
        for (uint256 i; i < ids.length; ++i) {
            Proposal storage p = _proposals[ids[i]];
            if (p.readyAt == 0) continue;
            (uint256 yes, uint256 needed) = tally(ids[i]);
            if (yes < needed) {
                p.readyAt = 0;
                emit ReadyReset(ids[i]);
            }
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
            if (amountIn > _free(tokenIn)) revert ZeroAmount(); // can't pitch money the crew doesn't have
            if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
            if (amountIn == 0 || tokenIn == tokenOut) revert ZeroAmount();
        } else if (kind == Kind.AddMember) {
            address m = abi.decode(data, (address));
            if (m == address(0) || isMember[m]) revert AlreadyMember();
        } else if (kind == Kind.SetRules) {
            (uint16 t, uint32 c) = abi.decode(data, (uint16, uint32));
            if (t <= 5000 || t > 10000 || c > MAX_COOL_OFF) revert BadRules();
            if (bornOpen && c < OPEN_MIN_COOL_OFF) revert BadRules();
        } else if (kind == Kind.SetJoins) {
            if (!bornOpen) revert BadRules();
        } else {
            if (bornOpen) revert BadRegistry(); // open crews can't be moved: closes the "vote in a fake registry" route
            address r = abi.decode(data, (address));
            if (r == address(0) || r.code.length == 0 || RheilonRegistry(r).baseAsset() != baseAsset) revert BadRegistry();
        }
    }

    function _trade(uint256 id, bytes memory data) internal {
        (address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut) =
            abi.decode(data, (address, address, uint256, uint256));
        if (!isHeld[tokenIn]) revert NotHeld(tokenIn);
        if (!registry.isSupported(tokenOut)) revert UnsupportedAsset(tokenOut);
        if (amountIn > _free(tokenIn)) revert ZeroAmount(); // never spends what members are owed
        if (_actionNear(tokenIn)) revert CorporateAction(tokenIn);
        if (_actionNear(tokenOut)) revert CorporateAction(tokenOut);
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

        uint256 received = _swapExact(tokenIn, tokenOut, swapIn);
        _checkBound(tokenIn, tokenOut, swapIn, received);

        if (feeOnOut && rate > 0) {
            fee = (received * rate) / 10000;
            received -= fee;
            if (fee > 0) IERC20(tokenOut).safeTransfer(treasury, fee);
        }
        if (received < minOut) revert Slippage(received, minOut);

        _untrackIfEmpty(tokenIn);
        emit Traded(id, tokenIn, tokenOut, amountIn, received, fee);
    }

    /// @dev Swaps exactly `swapIn` through the registry's adapter and returns what arrived. Reverts if the account
    ///      didn't spend exactly `swapIn`, or if the adapter kept any of it (a partial fill would leave the rest there).
    function _swapExact(address tokenIn, address tokenOut, uint256 swapIn) internal returns (uint256 received) {
        address adapter = registry.swapAdapter();
        uint256 before = IERC20(tokenOut).balanceOf(address(this));
        uint256 inBefore = IERC20(tokenIn).balanceOf(address(this));
        uint256 adapterBefore = IERC20(tokenIn).balanceOf(adapter);
        IERC20(tokenIn).forceApprove(adapter, swapIn);
        ISwapAdapter(adapter).swap(tokenIn, tokenOut, swapIn, 0, address(this));
        IERC20(tokenIn).forceApprove(adapter, 0);
        if (IERC20(tokenIn).balanceOf(adapter) != adapterBefore) revert PartialFill(swapIn, swapIn);
        uint256 spent = inBefore - IERC20(tokenIn).balanceOf(address(this));
        if (spent != swapIn) revert PartialFill(spent, swapIn);
        received = IERC20(tokenOut).balanceOf(address(this)) - before;
    }

    /// @dev Bound to the oracle: what came in must be worth at least what went out, minus MAX_TRADE_LOSS_BPS, whatever
    ///      minOut a pitch carries. If the oracle can't price what's sold, the trade is refused, except a sale into
    ///      USDG, which runs held to minOut alone so a crew is never stuck holding a token whose feed went stale or
    ///      was retired.
    function _checkBound(address tokenIn, address tokenOut, uint256 swapIn, uint256 received) internal view {
        (bool priced, uint256 vIn) = _tryValueOf(tokenIn, swapIn);
        if (priced) {
            uint256 vOut = _valueOf(tokenOut, received);
            if (vOut * 10000 < vIn * (10000 - MAX_TRADE_LOSS_BPS)) revert OracleBound(vOut, vIn);
        } else if (tokenOut != baseAsset) {
            revert OracleBound(0, 0);
        }
    }

    /// @dev Stock Tokens carry an ERC-8056 multiplier that changes on splits and dividends, and the token and its price
    ///      feed may not step at the same moment. Around a change the oracle can be off, so new money (deposits and
    ///      joins) and trades in that token pause: from 3 days before a pending change of more than 1% (smaller
    ///      dividend steps don't count) until 1 day after any change takes effect. Exits are unaffected. Tokens
    ///      without the extension (USDG, test tokens) are skipped.
    function _actionNear(address a) internal view returns (bool) {
        if (a == baseAsset) return false;
        try IERC8056(a).effectiveAt() returns (uint256 at) {
            if (block.timestamp >= at) return block.timestamp < at + 1 days; // just changed
            if (block.timestamp + 3 days < at) return false; // too far ahead to matter
            uint256 cur = IERC8056(a).uiMultiplier();
            uint256 nxt = IERC8056(a).newUIMultiplier();
            uint256 step = nxt > cur ? nxt - cur : cur - nxt;
            return step * 100 > cur;
        } catch {
            return false;
        }
    }

    function _noCorporateActionNear() internal view {
        for (uint256 i; i < _assets.length; ++i) {
            if (_actionNear(_assets[i])) revert CorporateAction(_assets[i]);
        }
    }

    /// @dev What the crew holds of an asset, not counting what departed members are still owed.
    function _free(address a) internal view returns (uint256) {
        return IERC20(a).balanceOf(address(this)) - owedTotal[a];
    }

    function _valueOf(address a, uint256 amount) internal view returns (uint256) {
        return a == baseAsset ? amount : IValueOracle(registry.oracle()).valueInBase(a, amount);
    }

    function _tryValueOf(address a, uint256 amount) internal view returns (bool, uint256) {
        if (a == baseAsset) return (true, amount);
        try IValueOracle(registry.oracle()).valueInBase(a, amount) returns (uint256 v) {
            return (true, v);
        } catch {
            return (false, 0);
        }
    }

    /// @dev ERC-20 transfer that reports failure instead of reverting (paused token, blocklist, no code).
    function _trySend(address token, address to, uint256 amount) internal returns (bool) {
        if (token.code.length == 0) return false;
        (bool ok, bytes memory ret) = token.call(abi.encodeCall(IERC20.transfer, (to, amount)));
        return ok && (ret.length == 0 || (ret.length == 32 && abi.decode(ret, (bool))));
    }

    function _addMember(address m) internal {
        if (m == address(0) || isMember[m]) revert AlreadyMember();
        if (_members.length >= seats) revert TooManyMembers();
        isMember[m] = true;
        memberEpoch[m] += 1;
        votesFrom[m] = block.timestamp; // votes at once; join() pushes it out by VOTE_DELAY
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
        if (a == baseAsset || _free(a) != 0) return;
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


// File contracts/RheilonAccountDeployer.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;


/// @title RheilonAccountDeployer
/// @notice Holds the account's code so the factory stays under the size limit. The factory creates it in its own
///         constructor and is the only caller it accepts, so every account it makes is one the factory listed.
contract RheilonAccountDeployer {
    address public immutable factory;

    error OnlyFactory();

    constructor() {
        factory = msg.sender;
    }

    function deploy(RheilonRegistry registry, string calldata name, address[] calldata members, RheilonAccount.Config calldata cfg)
        external
        returns (address)
    {
        if (msg.sender != factory) revert OnlyFactory();
        return address(new RheilonAccount(registry, name, members, cfg));
    }
}


// File contracts/RheilonFactory.sol

// Original license: SPDX_License_Identifier: MIT
pragma solidity 0.8.24;



/// @title RheilonFactory
/// @notice Opens a shared account for a crew. No owner, no fees to create. The caller is always the first member.
contract RheilonFactory {
    RheilonRegistry public immutable registry;
    /// @notice Holds the account code (kept apart so this contract stays under the size limit). Created here, and it
    ///         only answers to this factory.
    RheilonAccountDeployer public immutable deployer;
    address[] public allAccounts;
    mapping(address => address[]) internal _accountsOf;

    event AccountCreated(address indexed account, address indexed creator, string name, bool open, uint8 seats);

    constructor(RheilonRegistry registry_) {
        registry = registry_;
        deployer = new RheilonAccountDeployer();
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
        account = deployer.deploy(registry, name, members, RheilonAccount.Config(voteMode, open, seats, minJoin));
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
