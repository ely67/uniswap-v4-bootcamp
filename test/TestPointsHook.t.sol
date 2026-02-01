// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import {Test} from "forge-std/Test.sol";
 
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
 
import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
 
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
 
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
 
import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";
 
import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHook.sol";
 
contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {
 
	MockERC20 token; // our token to use in the ETH-TOKEN pool
 
	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;
 
	PointsHook hook;
 
	function setUp() public {
		deployFreshManagerAndRouters();

        token = new MockERC20("Test Token", "Test", 18);
		tokenCurrency = Currency.wrap(address(token));

        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG);
        // PointsHook constructor: (IPoolManager manager, address token)
        deployCodeTo("PointsHook.sol", abi.encode(manager, address(token)), address(flags));

        // Hook is already deployed/etched at `address(flags)` by deployCodeTo(...)
        hook = PointsHook(address(flags));

		token.approve(address(swapRouter), type(uint256).max);
		token.approve(address(modifyLiquidityRouter), type(uint256).max);

		(key, ) = initPool(ethCurrency, tokenCurrency, hook, 3000, SQRT_PRICE_1_1);

		uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
		uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

		uint256 ethToAdd = 0.003 ether;

		uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
			SQRT_PRICE_1_1,
			sqrtPriceAtTickUpper,
			ethToAdd
    	);

		uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
			sqrtPriceAtTickLower,
			SQRT_PRICE_1_1,
			liquidityDelta
		);

		modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
			key,
			ModifyLiquidityParams({
				tickLower: -60,
				tickUpper: 60,
				liquidityDelta: int256(uint256(liquidityDelta)),
				salt: bytes32(0)
			}),
			ZERO_BYTES
		);		
	}

	function test_swap() public {
		uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
		uint256 pointsBalanceBeforeSwap = hook.balanceOf(address(this), poolIdUint);

		bytes memory hookData = abi.encode(address(this), address(0));

		swapRouter.swap{value: 0.001 ether}(
			key,
			SwapParams({
				zeroForOne: true,
				amountSpecified: -0.001 ether,
				sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
			}),
			PoolSwapTest.TestSettings({
				takeClaims: false,
				settleUsingBurn: false
			}),
			hookData
		);

		uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint);
		assertEq(pointsBalanceAfterSwap - pointsBalanceBeforeSwap, 2 * 10 ** 14);
	}

	function test_add_liquidity() public {
		uint256 poolIdUint = uint256(PoolId.unwrap(key.toId()));
		uint256 pointsBalanceBeforeAddLiquidity = hook.balanceOf(address(this), poolIdUint);
		console.log("points before add liquidity:", pointsBalanceBeforeAddLiquidity);

		bytes memory hookData = abi.encode(address(this), address(0));

		uint256 eth = 0.1 ether;

		uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
		uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

		uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
			SQRT_PRICE_1_1,
			sqrtPriceAtTickUpper,
			eth
    	);

		uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
			sqrtPriceAtTickLower,
			SQRT_PRICE_1_1,
			liquidityDelta
		);

		modifyLiquidityRouter.modifyLiquidity{value: eth}(
			key,
			ModifyLiquidityParams({
				tickLower: -60,
				tickUpper: 60,
				liquidityDelta: int256(uint256(liquidityDelta)),
				salt: bytes32(0)
			}),
			hookData
		);

		uint256 pointsAfterAddLiquidity = hook.balanceOf(address(this), poolIdUint);
		console.log("points after add liquidity:", pointsAfterAddLiquidity);

		assertEq(pointsAfterAddLiquidity - pointsBalanceBeforeAddLiquidity, eth / 20);
	}
}