// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {PointsHook} from "../src/PointsHook.sol";

contract PointsHookScript is Script {
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    address internal constant POOL_MANAGER = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    // ERC20 token address on Base Sepolia (not deployed by me).
    // Chosen as a random existing token from BaseScan for testing/demo purposes.
    address internal constant TOKEN = 0x9fcd1C16CBdFb59523b04187c05C1e55aFb3a1a2;

    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG);

        bytes memory constructorArgs = abi.encode(IPoolManager(POOL_MANAGER), TOKEN);
        (address hookAddress, bytes32 salt) = HookMiner.find(CREATE2_DEPLOYER, flags, type(PointsHook).creationCode, constructorArgs);

        vm.startBroadcast(privateKey);
        PointsHook pointsHook = new PointsHook{salt: salt}(IPoolManager(POOL_MANAGER), TOKEN);
        require(address(pointsHook) == hookAddress, "hook address mismatch");
        vm.stopBroadcast();
    }
}