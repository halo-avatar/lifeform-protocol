/***
* MIT License
* ===========
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
 __         __     ______   ______     ______   ______     ______     __    __    
/\ \       /\ \   /\  ___\ /\  ___\   /\  ___\ /\  __ \   /\  == \   /\ "-./  \   
\ \ \____  \ \ \  \ \  __\ \ \  __\   \ \  __\ \ \ \/\ \  \ \  __<   \ \ \-./\ \  
 \ \_____\  \ \_\  \ \_\    \ \_____\  \ \_\    \ \_____\  \ \_\ \_\  \ \_\ \ \_\ 
  \/_____/   \/_/   \/_/     \/_____/   \/_/     \/_____/   \/_/ /_/   \/_/  \/_/ 
                                                                                  
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Interface/IAvatarMintRule.sol";

contract AvatarFactory is Ownable, ReentrancyGuard {

    using ECDSA for bytes32;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
     
    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    // //type hash
    // struct MintRule {
    //     address mintRule;
    //     uint256 udIndex;
    //     address stakeErc20;
    //     uint256 stakeErc20Amount;
    //     address costErc20;
    //     uint256 costErc20Amount;
    //     address erc721;
    //     uint256 [] children721;
    //     address erc1155;
    //     uint256 [] children1155;
    //     uint256 [] amount1155;
    //     bytes32 signCode;
    //     bytes wlSignature;    //wlSignature
    // }

    bytes32 public constant TYPE_HASH = keccak256(
        "MintRule(address mintRule,uint256 udIndex,address stakeErc20,uint256 stakeErc20Amount,address costErc20,uint256 costErc20Amount,address erc721,uint256[] children721,address erc1155,uint256[] children1155,uint256[] amount1155,bytes32 signCode,bytes wlSignature)"
    );

    address private _SIGNER;

    EnumerableSet.Bytes32Set private _signCodes;

    // for IAMs
    mapping(address => bool) public _IAMs;

    //mint rule map 
    EnumerableSet.AddressSet private _mintRules;
    
    bool public _isUserStart = false;
    bool public _onceSignCode = true;

    constructor(address SIGNER){
        //default iam
        addIAM(msg.sender);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("AvatarFactory"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );

        _SIGNER = SIGNER;
    }


    function setUserStart(bool start) public onlyOwner {
        _isUserStart = start;
    }

    function setOnceSignCode(bool enable) public onlyOwner {
        _onceSignCode = enable;
    }

    function addIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = true;
    }

    function removeIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = false;
    }

    function addMintRule(address rule) public onlyOwner {
        if(!_mintRules.contains(rule)){
            _mintRules.add(rule);
        }
    }

    function removeMintRule(address rule) public onlyOwner {
         if(!_mintRules.contains(rule)){
            _mintRules.remove(rule);
         }
    }

    function getMintRules() public view returns(address[] memory){
        return _mintRules.values();
    }

    function mintAvatar721(IAvatarMintRule.MintRule calldata mintData, bytes memory dataSignature) external nonReentrant
    {
        address origin = msg.sender;
        if(_IAMs[msg.sender] == false){
            require(!origin.isContract(), "lifeform: call to non-contract");
        }
        require( _isUserStart || _IAMs[msg.sender]  , "lifeform: can't mint" );

        if( _isUserStart ){
            if(_onceSignCode){
                require(!isExistSignCode(mintData.signCode),"invalid signCode!");
            }
            require(verify(mintData, msg.sender, dataSignature), "this sign is not valid");
            _signCodes.add(mintData.signCode);
        }

        require(_mintRules.contains(mintData.mintRule),"lifeform: invalid mintRule!" );

        IAvatarMintRule rule = (IAvatarMintRule)(mintData.mintRule);
        rule.mint(mintData);

    } 

   function updateSigner( address signer) public onlyOwner {
        _SIGNER = signer;
    }

    //check the state of a signCode
    function isExistSignCode(bytes32 signCode) view public returns(bool) {
        return _signCodes.contains(signCode);
    }

    //generate the whitelist user hash
    function hashWhiteList( address user, bytes32 signCode ) public pure returns (bytes32) {

        bytes32 message = keccak256(abi.encodePacked(user, signCode));
        // hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return message.toEthSignedMessageHash();
    }

    //generate the mintData hash
    function hashCondition(IAvatarMintRule.MintRule calldata mintData) public pure returns (bytes32) {

        // struct MintRule {
        //     address mintRule;
        //     uint256 udIndex;
        //     address stakeErc20;
        //     uint256 stakeErc20Amount;
        //     address costErc20;
        //     uint256 costErc20Amount;
        //     address erc721;
        //     uint256 [] children721;
        //     address erc1155;
        //     uint256 [] children1155;
        //     uint256 [] amount1155;
        //     bytes32 signCode;
        //     bytes wlSignature;    //wlSignature
        // }

        return keccak256(
            abi.encode(
                TYPE_HASH,
                mintData.mintRule,
                mintData.udIndex,
                mintData.stakeErc20,
                mintData.stakeErc20Amount,
                mintData.costErc20,
                mintData.costErc20Amount,
                mintData.erc721,
                keccak256(abi.encodePacked(mintData.children721)),
                mintData.erc1155,
                keccak256(abi.encodePacked(mintData.children1155)),
                keccak256(abi.encodePacked(mintData.amount1155)),
                mintData.signCode,
                keccak256(mintData.wlSignature))
        );
    }

    function hashDigest(IAvatarMintRule.MintRule calldata mintData) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hashCondition(mintData)
        ));
    }

    function verifySignature(bytes32 hash, bytes memory  signature) public view returns (bool) {
        //hash must be a soliditySha3 with accounts.sign
        return hash.recover(signature) == _SIGNER;
    }

    function verifyCondition(IAvatarMintRule.MintRule calldata mintData, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        bytes32 digest = hashDigest(mintData);
        return ecrecover(digest, v, r, s) == _SIGNER;    
    }

    function verify( IAvatarMintRule.MintRule calldata mintData, address user, bytes memory dataSignature ) public view returns (bool) {
       
        require(mintData.signCode != "","invalid sign code!");

        bytes32 digest = hashDigest(mintData);
        require(verifySignature(digest,dataSignature)," invalid dataSignatures! ");

        if(mintData.wlSignature.length >0 ){
            bytes32 hash = hashWhiteList(user, mintData.signCode);
            require( verifySignature(hash, mintData.wlSignature), "invalid wlSignature! ");
        }

        return true;
    }


}
