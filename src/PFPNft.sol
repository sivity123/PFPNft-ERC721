// SPDX-License-Identifier:MIT

pragma solidity ^0.8.30;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {
    ReentrancyGuard
} from "lib/openzeppelin-contracts-upgradeable/lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title Profile Picture NFT with phased allowlist and public mint
/// @author (add your name / handle)
/// @notice ERC721 profile picture collection with two minting gateways:
/// allowlisted users pay a discounted fee, while non-allowlisted users
/// mint through the public gateway at a higher fee.
/// @dev
/// - Uses a Merkle tree to validate allowlisted addresses.
/// - Enforces a minimum time window where only allowlisted users can mint.
/// - After the allowlist period, non-allowlisted users can mint via the
///   public gateway if they pay the public fee.
/// - Overpayments are automatically refunded to the minter.
/// - Metadata is returned fully on-chain as a Base64-encoded JSON data URI.

import {Merkle} from "@murky/src/Merkle.sol";

contract PFPNft is ERC721, ReentrancyGuard {
    using Strings for uint256;
    /*//////////////////////////////////////////////////////////////
                            TYPE DECLARATION
    //////////////////////////////////////////////////////////////*/

    enum Phase {
        CLOSED,
        ALLOWLISTED,
        PUBLIC_GATEWAY
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Reverts when a caller attempts to mint via the public path
     * while the contract is not yet in the public phase.
     * @param _currentPhase The current phase of the sale when the call was made.
     */
    error PFPNft__NotInThePublicPhase(Phase _currentPhase);
    /**
     *  @notice Reverts when the user sends less ETH than required for the
     *  chosen minting gateway.
     * @param _fee The amount of ETH sent by the caller.
     * @param _requiredFee The minimum required ETH for this gateway.
     */

    error PFPNft__InSufficientFees(uint256 _fee, uint256 _requiredFee);
    /**
     * @notice Reverts when an invalid gateway label is passed to the
     * pricing logic
     */
    error PFPNfft__InvalidGateway();
    /**
     * @notice Reverts when refunding excess ETH back to the caller fails.
     */
    error PFPNft__RepaymentFailed();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string private constant PUBLIC_IMAGE_URI =
        "https://azure-electoral-catshark-600.mypinata.cloud/ipfs/bafybeicdkeo5ekcvy3mikdkae7nerxfgjenzen2wvz2kkngym544ax36oy";
    string private constant ALLOWLISTED_IMAGE_URI =
        "https://azure-electoral-catshark-600.mypinata.cloud/ipfs/bafybeibkqusvvfr7jqn4rhbp6tkt7w2cfwsvrxeh5lsndmumrkorod6kjy";

    uint256 public allowListedCount;

    Phase private currentPhase;
    uint256 public s_tokenId;
    uint256 public s_totalSupply;
    uint256 private immutable i_maxTokenSupply;
    uint256 private immutable i_maxAllowlisted;
    uint256 private immutable i_minDurationToPublicGateway;
    uint256 private immutable i_allowListedTime;
    uint256 private immutable i_publicPayment;
    uint256 private immutable i_whileListPayment;
    uint256 private immutable i_feeForAllowlisted;
    uint256 private immutable i_feeForPublicGateway;
    bytes32 private immutable i_rootHash;
    address[] private s_allowlisted;
    string[2] private s_gateways = ["AllowListed", "Public"];

    mapping(uint256 tokenId => string imageUri) private s_tokenIdToImageUri;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event NftMinted(uint256 indexed s_tokenId, address indexed user);

    /**
     *  @notice Deploys the profile picture collection and configures
     *  supply caps, pricing and timing for the allowlist and public phases.
     *  @dev
     *  - Sets the Merkle root used for allowlist verification.
     *  - Starts the allowlist phase at the deployment timestamp.
     *  @param _maxTokenSupply Maximum number of NFTs that can ever be minted.
     *  @param _maxAllowlisted Maximum number of allowlisted mints allowed.
     *  @param _minimumDurationToPublic Minimum time (in seconds) after
     *  deployment during which only allowlisted mints are possible.
     *  After this duration, public minting is considered open.
     *  @param _fee4Allowlisted ETH fee required for allowlisted mints.
     *  @param _fee4Public ETH fee required for public gateway mints.
     * @param _rootHash Merkle root used to verify allowlisted addresses.
     */

    constructor(
        uint256 _maxTokenSupply,
        uint256 _maxAllowlisted,
        uint256 _minimumDurationToPublic,
        uint256 _fee4Allowlisted,
        uint256 _fee4Public,
        bytes32 _rootHash
    ) ERC721("PROFILE PICTURE NFT", "PFPNFT") {
        i_maxTokenSupply = _maxTokenSupply;
        i_maxAllowlisted = _maxAllowlisted;
        i_minDurationToPublicGateway = _minimumDurationToPublic;
        i_feeForAllowlisted = _fee4Allowlisted;
        i_feeForPublicGateway = _fee4Public;
        i_allowListedTime = block.timestamp;
        i_rootHash = _rootHash;
    }

    /**
     * @notice Mints a new profile picture NFT either as an allowlisted user
     *  (discounted fee) or through the public gateway (standard fee).
     *  @dev
     *  - If the provided Merkle proof is valid for `_to`, the caller is
     *    treated as allowlisted and the allowlist fee is applied.
     *  - If the proof is invalid, the caller must mint through the public
     *    gateway, which requires the public fee and only works once the
     *    public phase is open (`isPublic()`).
     *  - Any excess ETH above the required fee is refunded to `msg.sender`.
     *  - Uses `nonReentrant` to protect the refund logic.
     *  @param _to Address that will receive the newly minted NFT.
     *  @param _merkleProof Merkle proof showing that `_to` is in the
     *  allowlist tree, or an invalid proof if the caller is minting
     *  through the public gateway.
     */

    function mint(address _to, bytes32[] memory _merkleProof) public payable nonReentrant {
        uint256 fundsToRefund;
        bytes32 leafHash = keccak256((bytes.concat(keccak256(abi.encode(_to))))); // keccak256((bytes.concat(keccak256(abi.encode(_to, 25 * 1e18)))))
        if (!MerkleProof.verify(_merkleProof, i_rootHash, leafHash)) {
            if (!isPublic()) revert PFPNft__NotInThePublicPhase(currentPhase);
            fundsToRefund = _overpaymentHandling(msg.value, s_gateways[1]); // public gateway
            s_tokenIdToImageUri[s_tokenId] = PUBLIC_IMAGE_URI;
        } else {
            fundsToRefund = _overpaymentHandling(msg.value, s_gateways[0]); //allowlisted
            s_tokenIdToImageUri[s_tokenId] = ALLOWLISTED_IMAGE_URI;
            allowListedCount += 1;
        }

        (bool success,) = payable(msg.sender).call{value: fundsToRefund}("");

        if (!success) revert PFPNft__RepaymentFailed();

        _safeMint(_to, s_tokenId);
        s_totalSupply += 1;
        s_tokenId = s_totalSupply;
        emit NftMinted(s_tokenId, _to);
    }

    /**
     * @notice Returns the metadata URI for a given token ID.
     *  @dev
     *  - Metadata is generated fully on-chain as a JSON document:
     *    { name, description, image }.
     *  - The JSON is Base64-encoded and wrapped in a `data:application/json;base64,`
     *    URI so that wallets and marketplaces can read it directly.
     *  @param _tokenId The token ID to query.
     *  @return A data URI containing the Base64-encoded JSON metadata.
     */

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        string memory imageUri = s_tokenIdToImageUri[_tokenId];

        bytes memory dataURI = abi.encodePacked(
            '{"name":"',
            name(),
            " #",
            _tokenId.toString(),
            '","description":"Role based NFT with random category",',
            '"image":"',
            imageUri,
            '"}'
        );

        return string(abi.encodePacked(_baseURI(), Base64.encode(dataURI)));
    }

    /**
     *  @notice Returns the base URI prefix used for token metadata.
     *  @dev Always returns the data URI prefix for Base64-encoded JSON.
     *  This is concatenated with the encoded metadata in {tokenURI}.
     *  @return The constant base URI string `data:application/json;base64,`.
     */

    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    /**
     *  @notice Indicates whether the public minting gateway is currently open.
     *  @dev
     *  The public phase opens after `i_minDurationToPublicGateway`
     *  seconds have passed since deployment (stored in `i_allowListedTime`).
     *  @return True if the current timestamp is past the public-open time,
     *  false otherwise.
     */

    function isPublic() public view returns (bool) {
        return block.timestamp >= i_minDurationToPublicGateway + i_allowListedTime;
    }

    /**
     *    @notice Computes and returns any overpaid ETH for a given gateway,
     *  reverting if the caller has underpaid.
     *  @dev
     *  - For the allowlisted gateway (`s_gateways[0]`), `_fee` must be at
     *    least `i_feeForAllowlisted`.
     *  - For the public gateway (`s_gateways[1]`), `_fee` must be at least
     *    `i_feeForPublicGateway`.
     *  - If `_fee` is less than the required amount, the call reverts with
     *    {PFPNft__InSufficientFees}.
     *  - If `_gateway` does not match any known gateway string, the call
     *    reverts with {PFPNfft__InvalidGateway}.
     *  @param _fee The amount of ETH sent by the caller.
     *  @param _gateway The gateway label being used
     *  (`"AllowListed"` or `"Public"`).
     *  @return OverFund The amount of ETH to refund to the caller.
     */

    function _overpaymentHandling(uint256 _fee, string memory _gateway) public view returns (uint256 OverFund) {
        if (keccak256(abi.encodePacked(_gateway)) == keccak256(abi.encodePacked(s_gateways[0]))) {
            if (_fee < i_feeForAllowlisted) {
                revert PFPNft__InSufficientFees(_fee, i_feeForAllowlisted);
            } else {
                OverFund = _fee - i_feeForAllowlisted;
                return OverFund;
            }
        } else if (keccak256(abi.encodePacked(_gateway)) == keccak256(abi.encodePacked(s_gateways[1]))) {
            if (_fee < i_feeForPublicGateway) {
                revert PFPNft__InSufficientFees(_fee, i_feeForPublicGateway);
            } else {
                OverFund = _fee - i_feeForPublicGateway;
                return OverFund;
            }
        } else {
            revert PFPNfft__InvalidGateway();
        }
    }
    /**
     *  @notice Returns two example invalid Merkle leaf hashes.
     *  @dev
     *  These values can be used in tests or off-chain tooling to simulate or by public users to call mint with
     *  invalid Merkle proofs.
     */

    function getInvalidProofs() external pure returns (bytes32, bytes32) {
        return (keccak256(abi.encode("INVALID_PROOF1")), keccak256(abi.encode("INVALID_PROOF2")));
    }
}

