// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";
import "./MockERC20.sol";

contract DeployContractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        address poolManager = address(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A);
        PoolKey memory pool = PoolKey({ 
            currency0: Currency.wrap(address(0x4F26A0466F08BA8Ee601C661C0B2e8d75996a48c)),
            currency1: Currency.wrap(address(0xb7a5484C5688C2b462aAC4F6A894dF673CA4f194)), 
            fee: 500,                     
            tickSpacing: 60,             
            hooks: IHooks(address(0))             
        });
        uint160 sqrtPriceX96 = 79228162514264337593543950336; 

        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "initialize((address,address,uint24,int24,address),uint160)",
            pool,
            sqrtPriceX96
        );

        (bool success, ) = poolManager.call(encodedFunctionCall);
        require(success, "Failed to initialize pool");

        vm.stopBroadcast();
    }
}