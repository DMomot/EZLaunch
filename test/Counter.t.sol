// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/SwapHook.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IAllowanceTransfer} from "v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import "./MockERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract SwapHookTest is Test {
    IPoolManager public poolManager;
    SwapHook public swapHook;

    uint256 deadline = block.timestamp + 60000;


    MockERC20 public token0;
    MockERC20 public token1;
    address currency0;
    address currency1;

    uint24 public lpFee = 0;       
    int24 public tickSpacing = 1;
    uint160 public sqrtPriceX96 = 79228162514264337593543950336;
    address positionManagerAddress = address(0x1B1C77B606d13b09C84d1c7394B96b147bC03147);
    address permit2Address = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address poolManagerAddress = address(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A);
    address poolSwapTestAddress = address(0xe49d2815C231826caB58017e214Bed19fE1c2dD4);

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;
    

    function setUp() public {
        
        token1 = new MockERC20(10**15, "WETH", "WETH");
        token0 = new MockERC20(10**27, "Memecoin", "MEME");

        currency0 = address(token0);
        currency1 = address(token1);

        // recipient = address(this);
        poolManager = IPoolManager(poolManagerAddress);

    }

    function testInitPoolMintLiq() public {

        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG 
                // | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144)
        );

        bytes memory constructorArgs = abi.encode(poolManager);

        deployCodeTo("SwapHook.sol:SwapHook", constructorArgs, flags);
        swapHook = SwapHook(flags);

        // if (currency0 > currency1) {
        //     (currency0, currency1) = (currency1, currency0);
        // }

        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(swapHook))
        });

        poolManager.initialize(pool, sqrtPriceX96);


        // uint256 balanceToken0Before = token0.balanceOf(address(this));
        // uint256 balanceToken1Before = token1.balanceOf(address(this));

        // token0.approve(address(permit2Address), 10000 ether);
        // token1.approve(address(permit2Address), 10000 ether);

        // IAllowanceTransfer(address(permit2Address)).approve(address(token0), positionManagerAddress, type(uint160).max, type(uint48).max);
        // IAllowanceTransfer(address(permit2Address)).approve(address(token1), positionManagerAddress, type(uint160).max, type(uint48).max);

        // bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        // bytes[] memory params = new bytes[](2);
        // params[0] = abi.encode(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);

        // params[1] = abi.encode(Currency.wrap(currency0), Currency.wrap(currency1));


        // IPositionManager posm = IPositionManager(positionManagerAddress);

        // posm.modifyLiquidities(
        //     abi.encode(actions, params),
        //     deadline
        // );


        actionSwap(pool, -100, true);
        // actionSwap(pool, 200, false);
        // actionSwap(pool, 300, true);

        Currency.wrap(currency0).balanceOfSelf();
        Currency.wrap(currency1).balanceOfSelf();
    }

    function actionSwap(PoolKey memory pool, int256 amount, bool zeroForOne) public{
        token0.approve(address(poolSwapTestAddress), 10000 ether);
        token1.approve(address(poolSwapTestAddress), 10000 ether);

        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amount,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT
        });

        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        PoolSwapTest swapRouter = PoolSwapTest(poolSwapTestAddress);

        swapRouter.swap(pool, swapParams, testSettings, bytes(""));
    }
}