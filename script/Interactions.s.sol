// SPDX-License-Identifier:MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {DeployPFPNft} from "script/DeployPFPNft.s.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {PFPNft} from "src/PFPNft.sol";
contract Interactions is Script{

PFPNft nft ;
uint256 payableAmount;
bytes32[] proofs;
// address to = 0x002a5e5E33990194FB51E6dE9a86b6aabb293cBB;
// bytes32 P1 = 0xb020d7f4296a1630fca94fa7b375d844bdf7a6eb80d6c57d65896a2cad9a1dce;
// bytes32 P2 = 0x485cced89826cf7e0bb1a1f764abd959274947ab8970b4ee860ef2762bd68d0a;

// bytes32[] proofs = [P1,P2];
    function run(uint256 _payableAmount,address to,bytes32 proof1,bytes32 proof2) external returns(bool){
        payableAmount = _payableAmount;
        nft = PFPNft(DevOpsTools.get_most_recent_deployment("PFPNft", 11155111));
        proofs = [proof1,proof2]; 
        mint(to,proofs);
        return true;

    }

    function mint(address _to,bytes32[] memory _proofs) public {
        vm.startBroadcast();
        nft.mint{value:payableAmount}(_to,_proofs);
        vm.stopBroadcast();
    }



}