//SPDX License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {TokenPool} from "@ccip/contracts/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/v0.8/ccip/libraries/RateLimiter.sol";

contract ConfigurePoolScript is Script {
    function run(
        address localPool,
        uint64 remoteChainSelector,
        address remotePool,
        address remoteToken,
        bool outBoundRateLimiterEnabled,
        uint128 outBoundRateLimiterCapacity,
        uint128 outBoundRateLimiterRate,
        bool inBoundRateLimiterEnabled,
        uint128 inBoundRateLimiterCapacity,
        uint128 inBoundRateLimiterRate
    ) public {
        vm.startBroadcast();
        bytes memory remotePoolAddress = abi.encode(remotePool);
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: true,
            remotePoolAddress: remotePoolAddress,
            remoteTokenAddress: abi.encode(remoteToken),
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: outBoundRateLimiterEnabled,
                capacity: outBoundRateLimiterCapacity,
                rate: outBoundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: inBoundRateLimiterEnabled,
                capacity: inBoundRateLimiterCapacity,
                rate: inBoundRateLimiterRate
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}
