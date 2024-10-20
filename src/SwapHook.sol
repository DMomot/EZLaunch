// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;


import "forge-std/Test.sol";
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from  "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {Math} from "./libraries/Math.sol";


contract SwapHook is BaseHook, ERC20, Test {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    event SwapHookEvent(uint256 count);

    
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    Currency public immutable currency0;
    Currency public immutable currency1;

    uint128 private reserves0 = 10 ** 15; // Initial WETH liquidity
    uint128 private reserves1 = 10 ** 27; // Initial Token liquidity
    uint256 lpTotalSupply = 10 ** 18; // Initial LP tokens

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(uint256 amountIn, uint256 amountOut);
    event Sync(uint128 reserves0, uint128 reserves1);

    // keccak(DeltaUnspecified) - 1
    bytes32 constant DELTA_UNSPECIFIED_SLOT = 0x2e5feb220472ad9c92768617797b419bfabdc71375060ca8a1052c1ad7a5383b;

    error BalanceOverflow();
    error InvalidInitialization();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurnt();
    error AddLiquidityDirectToHook();
    error IncorrectSwapAmount();


    constructor(IPoolManager _poolManager) 
        BaseHook(_poolManager) 
        ERC20("Test", "TST") 
    {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

     function getReserves() public view returns (uint128 _reserves0, uint128 _reserves1) {
        _reserves0 = reserves0;
        _reserves1 = reserves1;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bool exactIn = (params.amountSpecified < 0);

        uint256 amountIn;
        uint256 amountOut;
        if (exactIn) {
            amountIn = uint256(-params.amountSpecified);
            amountOut = _getAmountOut(params.zeroForOne, amountIn);
        } else {
            amountOut = uint256(params.amountSpecified);
            amountIn = _getAmountIn(params.zeroForOne, amountOut);
        }

        (Currency inputCurrency, Currency outputCurrency) = _getInputOutput(key, params.zeroForOne);

        // take the input tokens of the swap into the pair
        poolManager.mint(address(this), CurrencyLibrary.toId(inputCurrency), amountIn);
        require(amountOut <= type(int128).max, "Amount exceeds int128 limit");
        require(balanceOf(address(this), CurrencyLibrary.toId(outputCurrency)) >= amountOut, "Insufficient balance to burn");
        poolManager.burn(address(this), CurrencyLibrary.toId(outputCurrency), amountOut);


        uint256 balance0 = poolManager.balanceOf(address(this), CurrencyLibrary.toId(currency0));
        uint256 balance1 = poolManager.balanceOf(address(this), CurrencyLibrary.toId(currency1));

        _update(balance0, balance1);

        // amountIn positive as hook takes it, amountOut negative as hook gives it
        int128 deltaUnspecified = exactIn ? -int128(uint128(amountOut)) : int128(uint128(amountIn));
        assembly {
            tstore(DELTA_UNSPECIFIED_SLOT, deltaUnspecified)
        }

        emit Swap(amountIn, amountOut);

        // return -amountSpecified to no-op the concentrated liquidity swap
        // return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, uint24(params.amountSpecified));
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, uint24(0));
    }

    function _getInputOutput(PoolKey calldata key, bool zeroForOne)
        internal
        pure
        returns (Currency input, Currency output)
    {
        (input, output) = zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        if (balance0 > type(uint128).max || balance1 > type(uint128).max) revert BalanceOverflow();
        reserves0 = uint128(balance0);
        reserves1 = uint128(balance1);
        emit Sync(reserves0, reserves1);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function _getAmountOut(bool zeroForOne, uint256 amountIn) internal view returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");

        (uint256 reservesIn, uint256 reservesOut) = zeroForOne ? (reserves0, reserves1) : (reserves1, reserves0);
        require(reserves0 > 0 && reserves1 > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reservesOut;
        uint256 denominator = (reservesIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function _getAmountIn(bool zeroForOne, uint256 amountOut) internal view returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");

        (uint256 reservesIn, uint256 reservesOut) = zeroForOne ? (reserves0, reserves1) : (reserves1, reserves0);
        require(reservesIn > 0 && reservesOut > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");

        uint256 numerator = reservesIn * amountOut * 1000;
        uint256 denominator = (reservesOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external returns (uint256 liquidity) {
        console.log("minting");
        (uint128 _reserves0, uint128 _reserves1) = getReserves();
        console.log("reserves0: %s, reserves1: %s", _reserves0, _reserves1);

        // The caller has already minted 6909s on the PoolManager to this address
        uint256 balance0 = poolManager.balanceOf(address(this), CurrencyLibrary.toId(currency0));
        uint256 balance1 = poolManager.balanceOf(address(this), CurrencyLibrary.toId(currency1));
        uint256 amount0 = balance0 - _reserves0;
        uint256 amount1 = balance1 - _reserves1;

        liquidity = Math.min((amount0 * lpTotalSupply)/_reserves0, (amount1 * lpTotalSupply)/_reserves1);
        if (liquidity == 0) revert InsufficientLiquidityMinted();
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        console.log("burning");
        uint256 balance0 = poolManager.balanceOf(address(this), CurrencyLibrary.toId(currency0));
        uint256 balance1 = poolManager.balanceOf(address(this), CurrencyLibrary.toId(currency1));
        uint256 liquidity = balanceOf(address(this));
        console.log(balance0, balance1, liquidity);

        amount0 = uint256((liquidity * balance0)/lpTotalSupply); // using balances ensures pro-rata distribution
        amount1 = uint256((liquidity * balance1)/lpTotalSupply); // using balances ensures pro-rata distribution
        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurnt();

        _burn(address(this), liquidity);

        _burn6909s(amount0, amount1, to);
        balance0 -= amount0;
        balance1 -= amount1;

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function _burn6909s(uint256 amount0, uint256 amount1, address to) internal {
        poolManager.unlock(abi.encode(amount0, amount1, to));
    }

}