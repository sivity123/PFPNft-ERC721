// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PFPNft} from "../src/PFPNft.sol";

contract DeployPFPNft is Script {

    //0x79d59bb2d6bd1673c55e50603dc739fc68e8938019df2b5a2b5691ebc471cffc, sepolia root hash
    
        uint256 maxTokenSupply = 15;
        uint256 maxAllowlisted = 4;
        uint256 minimumDurationToPublic = 2 minutes;
        uint256 fee4Allowlisted = 1 * 1e16;
        uint256 fee4Public = 2 * 1e16;
        bytes32 rootHash;
    
    function run(bytes32 _rootHash) external returns (PFPNft deployed) {
        rootHash = _rootHash;
        vm.startBroadcast();
        deployed = new PFPNft(
        maxTokenSupply,
        maxAllowlisted, 
        minimumDurationToPublic,
        fee4Allowlisted,
         fee4Public,
         rootHash
        );
        vm.stopBroadcast();
    }
}


