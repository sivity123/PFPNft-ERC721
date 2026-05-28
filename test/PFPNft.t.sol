// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import {PFPNft} from "../src/PFPNft.sol";
import {DeployPFPNft} from "../script/DeployPFPNft.s.sol";

contract PFPNftTest is Test {
    using stdJson for string;
    PFPNft public nft;
    DeployPFPNft public deployer;

    uint256 maxTokenSupply = 15;
    uint256 maxAllowlisted = 4;
    uint256 minimumDurationToPublic = 2 minutes;
    uint256 fee4Allowlisted = 1 * 1e16;
    uint256 fee4Public = 2 * 1e16;

    bytes32 rootHash;
    bytes32 P14User1 = 0x208697df1b2d4c083944c10909fe1ed6e99c1eaccff33ba129464b28f8245f01;
    bytes32 P24User1 = 0x9c02c1ddfbbf49c327b6fefe475cdec1ea15a94da878683f53c6e59f7725e396;
    bytes32[] proofOfUser1 = [P14User1, P24User1];

    address public owner = DEFAULT_SENDER;
    address public user1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public user2 = makeAddr("user2");
    address public attacker = makeAddr("attacker");
    address public sepoliaUser = 0x002a5e5E33990194FB51E6dE9a86b6aabb293cBB;

    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant SEND_VALUE = 1 ether;

    function setUp() public {
        if (block.chainid == 31337) {
            string memory json = vm.readFile("script/target/output.json");
            string memory key = "$[0].root";
            rootHash = vm.parseBytes32(json.readString(key));

            vm.deal(owner, STARTING_BALANCE);
            vm.deal(user1, STARTING_BALANCE);
            vm.deal(user2, STARTING_BALANCE);
            vm.deal(attacker, STARTING_BALANCE);
            nft = new PFPNft(
                maxTokenSupply, maxAllowlisted, minimumDurationToPublic, fee4Allowlisted, fee4Public, rootHash
            );
        } else if (block.chainid == 11155111) {
            user1 = sepoliaUser;

            string memory json = vm.readFile("script/targetSepolia/sepoliaOutput.json");
            string memory key = "$[0].root";
            string memory keyProof1 = "$[0].proof[0]";
            string memory keyProof2 = "$[0].proof[2]";
            rootHash = vm.parseBytes32(json.readString(key));
            P14User1 = vm.parseBytes32(json.readString(keyProof1));
            P24User1 = vm.parseBytes32(json.readString(keyProof2));
            
            proofOfUser1 = [P14User1, P24User1];

            deployer = new DeployPFPNft();

            nft = deployer.run(rootHash);
        }
    }

    // ==================== HAPPY PATH ====================

    function test_SomeFunction_Works() public {
        uint256 expectedAllowlistedCount = 1;
        vm.prank(user1);
        vm.warp(block.timestamp + 121 seconds);
        vm.roll(1);
        nft.mint{value: 10 * 1e15}(user1, proofOfUser1);
        uint256 actualAllowListedCount = nft.allowListedCount();
        assertEq(expectedAllowlistedCount, actualAllowListedCount);
    }
}
