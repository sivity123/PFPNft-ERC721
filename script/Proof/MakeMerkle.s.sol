// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {ScriptHelper} from "murky/script/common/ScriptHelper.sol";

contract MakeMerkle is Script, ScriptHelper {
    using stdJson for string;

    Merkle private m = new Merkle();

    function getValuesByIndex(uint256 i, uint256 j) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i), ".", vm.toString(j));
    }

    function generateJsonEntries(
        string memory _inputs,
        string memory _proof,
        string memory _root,
        string memory _leaf
    ) internal pure returns (string memory) {
        return string.concat(
            "{",
            "\"inputs\":", _inputs, ",",
            "\"proof\":", _proof, ",",
            "\"root\":\"", _root, "\",",
            "\"leaf\":\"", _leaf, "\"",
            "}"
        );
    }

    function run(uint256 chainId) public {
        string memory inputPath = "/script/target/input.json";
        string memory outputPath = "/script/target/output.json";

        if (chainId == 11155111) {
            inputPath = "/script/targetSepolia/sepoliaInput.json";
            outputPath = "/script/targetSepolia/sepoliaOutput.json";
        }

        string memory fullInputPath = string.concat(vm.projectRoot(), inputPath);
        string memory fullOutputPath = string.concat(vm.projectRoot(), outputPath);

        console.log("Generating Merkle Proof for %s", fullInputPath);

        string memory elements = vm.readFile(fullInputPath);
        string[] memory types = elements.readStringArray(".types");
        uint256 count = elements.readUint(".count");

        require(types.length == 1, "MakeMerkle: expected one type");
        require(compareStrings(types[0], "address"), "MakeMerkle: type must be address");

        bytes32[] memory leafs = new bytes32[](count);
        string[] memory inputs = new string[](count);
        string[] memory outputs = new string[](count);

        for (uint256 i = 0; i < count; ++i) {
            string[] memory input = new string[](1);
            bytes32[] memory data = new bytes32[](1);

            address value = elements.readAddress(getValuesByIndex(i, 0));
            data[0] = bytes32(uint256(uint160(value)));
            input[0] = vm.toString(value);

            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
            inputs[i] = stringArrayToString(input);
        }

        bytes32 rootBytes = m.getRoot(leafs);
        string memory root = vm.toString(rootBytes);

        for (uint256 i = 0; i < count; ++i) {
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            string memory leaf = vm.toString(leafs[i]);
            outputs[i] = generateJsonEntries(inputs[i], proof, root, leaf);
        }

        string memory output = stringArrayToArrayString(outputs);
        vm.writeFile(fullOutputPath, output);

        console.log("DONE: The output is found at %s", fullOutputPath);
    }
}