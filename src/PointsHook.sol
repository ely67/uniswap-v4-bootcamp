// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ERC1155} from "solmate/src/tokens/ERC1155.sol";

import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
contract PointsHook is BaseHook, ERC1155 {
    
    Currency public immutable TOKEN;

    constructor(IPoolManager _manager, address token) BaseHook(_manager) {
        require(token != address(0), "TOKEN_ZERO_ADDRESS");
        TOKEN = Currency.wrap(token);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return 
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false, 
                afterAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function uri(uint256 id) public view virtual override returns (string memory) {
        return "https://api-example.com/token/{id}";
    }


    function _afterSwap(address, PoolKey calldata key, SwapParams calldata swapParams, BalanceDelta delta, bytes calldata hookData)
        internal
        override
        returns (bytes4, int128)
    {
        if(!key.currency0.isAddressZero()) {
            return (this.afterSwap.selector, 0);
        }

        // Validate that currency1 is our configured ERC20 token
        if (!(key.currency1 == TOKEN)) {
            return (this.afterSwap.selector, 0);
        }
        

        if(!swapParams.zeroForOne) {
            return (this.afterSwap.selector, 0);
        }

        (address user, address referral) = abi.decode(hookData, (address, address));

        uint256 ethSpendAmount = uint256(int256(-delta.amount0()));

        // Referral bonus rule:
        // - If referral != 0 and referral != user, award a bonus to the referral address.
        // - Here it's set to 5% of `ethSpendAmount` (since /20).
        uint256 pointsForreferral;
        if(referral != address(0) && user != referral) {
            pointsForreferral = ethSpendAmount / 20;
        }

        uint256 pointsForSwap = ethSpendAmount / 5;

        _assignPoints(key.toId(), hookData, pointsForSwap, pointsForreferral);
        return (this.afterSwap.selector, 0);
    }

    function _afterAddLiquidity(
        address,
        PoolKey calldata key,
        ModifyLiquidityParams calldata modifyLiqudityParams,
        BalanceDelta delta,
        BalanceDelta,
        bytes calldata hookData
    ) internal override returns (bytes4, BalanceDelta) {
        if(!key.currency0.isAddressZero()) {
            return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
        }

        if(!(key.currency1 == TOKEN)) {
            return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
        }

        uint256 ethAmount = uint256(int256(-delta.amount0()));
        uint256 pointsForAddLiquidity = ethAmount / 20;

        _assignPoints(key.toId(), hookData, pointsForAddLiquidity, 0);
        return (this.afterAddLiquidity.selector, BalanceDeltaLibrary.ZERO_DELTA);
    }

    function _assignPoints(
        PoolId poolId,
        bytes calldata hookData,
        uint256 userPoints,
        uint256 referralPoints
    ) internal {
        if(hookData.length == 0) return;

        (address user, address referral) = abi.decode(hookData, (address, address));
        uint256 poolIdUint = uint256(PoolId.unwrap(poolId));

        if(referralPoints > 0) {
            _mint(referral, poolIdUint, referralPoints, "");
        }

        if(user == address(0)) return;

        _mint(user, poolIdUint, userPoints, "");
    }
}