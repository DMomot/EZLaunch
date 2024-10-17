// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniswapV4PoolInitializer {
    IPoolManager public poolManager;
    address public poolManagerAddress;

    constructor(address _poolManager) {
        poolManager = IPoolManager(_poolManager);
        poolManagerAddress = _poolManager;
    }

    function initializePool(
        address currency0,
        address currency1,
        uint24 lpFee,
        int24 tickSpacing,
        address hookContract,
        uint160 sqrtPriceX96
    ) external returns (bytes memory tick) {
        PoolKey memory pool = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: IHooks(hookContract)
        });

        // Пустые данные для хука
        bytes memory emptyHookData = "";

        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "initialize((address,address,uint24,int24,address),uint160,bytes)",
            pool,
            sqrtPriceX96,
            emptyHookData
        );

        (bool success, bytes memory _tick) = poolManagerAddress.call(encodedFunctionCall);

        require(success, "Failed to initialize pool");

        return (_tick);
    }


    function mintPosition(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        address recipient,
        bytes memory hookData,
        address currency0,
        address currency1
    ) external {
        // Убедитесь, что контракт имеет разрешение для перевода токенов
        IERC20(currency0).transferFrom(msg.sender, address(this), amount0Max);
        IERC20(currency1).transferFrom(msg.sender, address(this), amount1Max);

        // Действия, которые должны быть выполнены
        bytes memory actions = abi.encodePacked(Actions.MINT_POSITION, Actions.SETTLE_PAIR);

        // Параметры для MINT_POSITION
        bytes;
        params[0] = abi.encode(poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);

        // Параметры для SETTLE_PAIR
        params[1] = abi.encode(Currency.wrap(currency0), Currency.wrap(currency1));

        // Определяем дедлайн для операции (например, 60 секунд)
        uint256 deadline = block.timestamp + 60;

        // Вызываем метод modifyLiquidities для создания позиции
        positionManager.modifyLiquidities(
            abi.encode(actions, params),
            deadline
        );
    }
}