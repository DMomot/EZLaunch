// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Counter.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";

contract UniswapV4PoolInitializerTest is Test {
    UniswapV4PoolInitializer public initializer;
    address public poolManager = address(0xE8E23e97Fa135823143d6b9Cba9c699040D51F70);
    IPoolManager public _poolManager;

    // Mock tokens
    address public token0 = address(0x123);
    address public token1 = address(0x456);

    // Pool parameters
    uint24 public lpFee = 500;           // 0.05%
    int24 public tickSpacing = 60;
    address public hookContract = address(0);  // Нет хука в данном случае
    uint160 public sqrtPriceX96 = 79228162514264337593543950336; // Пример начальной цены

    function setUp() public {

        initializer = new UniswapV4PoolInitializer(poolManager);
        _poolManager = IPoolManager(poolManager);
    }

    function testInitializePool() public {
        bytes memory tick = initializer.initializePool(
            token0,
            token1,
            lpFee,
            tickSpacing,
            hookContract,
            sqrtPriceX96
        );
    }

}