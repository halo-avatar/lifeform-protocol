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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./Interface/ICartoonMintRule.sol";

contract CartoonFactory is Ownable, ReentrancyGuard {

    event eUpdateSigner(
        address signer,
        uint256 blockNum
    );

    using ECDSA for bytes32;
    using Address for address;

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
    //     uint256 limitTimes;
    //     uint256 mintType;
    //     bytes32 signCode;
    //     bytes wlSignature;    //wlSignature
    // }

    bytes32 public constant TYPE_HASH = keccak256(
        "MintRule(address mintRule,uint256 udIndex,address stakeErc20,uint256 stakeErc20Amount,address costErc20,uint256 costErc20Amount,uint256 limitTimes,uint256 mintType,bytes32 signCode,bytes wlSignature)"
    );

    //signCodes table
    EnumerableSet.Bytes32Set private _signCodes;

    //mint rule map 
    EnumerableSet.AddressSet private _mintRules;

    //mint limits map
    mapping(uint256 => mapping(address => uint256)) public _mintTimes;

    //
    address public _SIGNER;

    //
    address public _stakeErc20;
    address public _costErc20;
    uint256 public _stakeAmount;
    uint256 public _costAmount;
    
    bool public _onceSignCode = true;

    constructor(address SIGNER,
                address stakeErc20,
                uint256 stakeAmount,
                address costErc20,
                uint256 costAmount
        )
    {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("CartoonFactory"),
                keccak256("2"),
                block.chainid,
                address(this)
            )
        );

        require(SIGNER != address(0x0), "SIGNER is zero address!");
        require(costErc20 != address(0x0), "costErc20 is zero address!");
        require(stakeErc20 != address(0x0), "stakeErc20 is zero address!");

        _SIGNER = SIGNER;

        _costErc20 = costErc20;
        _costAmount = costAmount;
        _stakeErc20 = stakeErc20;
        _stakeAmount = stakeAmount;
    }

    function updateCostErc20(address costErc20, uint256 costAmount) public onlyOwner
    {
        require(costErc20 != address(0x0), "costErc20 is zero address!");

        _costErc20 = costErc20;
        _costAmount = costAmount;
    }

    function updateStakeErc20(address stakeErc20, uint256 stakeAmount) public onlyOwner
    {
        require(stakeErc20 != address(0x0), "stakeErc20 is zero address!");

        _stakeErc20 = stakeErc20;
        _stakeAmount = stakeAmount;
    }

    function setOnceSignCode(bool enable) public onlyOwner {
        _onceSignCode = enable;
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

    function mintAvatar721(ICartoonMintRule.MintRule calldata mintData, bytes memory dataSignature) public nonReentrant
    {
        require(!msg.sender.isContract(), "lifeform: call to non-contract");
        require(_mintRules.contains(mintData.mintRule),"lifeform: invalid mintRule!" );
        ICartoonMintRule rule = (ICartoonMintRule)(mintData.mintRule);

        if(mintData.wlSignature.length>0 ){
        
            if(_onceSignCode){
                require(!isExistSignCode(mintData.signCode),"lifeform: invalid signCode!");
            }
            require(verify(mintData, msg.sender, dataSignature), "lifeform: this sign is not valid");
            require(_mintTimes[mintData.mintType][msg.sender]< mintData.limitTimes,"lifeform: mint times overflow!" );

            _signCodes.add(mintData.signCode);
            _mintTimes[mintData.mintType][msg.sender] += 1;

            rule.mint(mintData.udIndex,mintData.stakeErc20,mintData.stakeErc20Amount,mintData.costErc20,mintData.costErc20Amount,mintData.mintType);
         }
         else{
            
            require( _stakeAmount>0 || _costAmount>0,"lifeform: invalid mint rule" );
            rule.mint(mintData.udIndex,_stakeErc20,_stakeAmount,_costErc20,_costAmount, 0);
         }
        
    } 

   function updateSigner( address SIGNER) public onlyOwner {

       require(SIGNER != address(0x0), "SIGNER is zero address!");

        _SIGNER = SIGNER;

        emit eUpdateSigner(SIGNER,block.number);
    }

    //check the mint times
    function getTheMintTimes(uint256 mintType, address user) view public returns(uint256) {
        return _mintTimes[mintType][user];
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
    function hashCondition(ICartoonMintRule.MintRule calldata mintData) public pure returns (bytes32) {

        // struct MintRule {
        //     address mintRule;
        //     uint256 udIndex;
        //     address stakeErc20;
        //     uint256 stakeErc20Amount;
        //     address costErc20;
        //     uint256 costErc20Amount;
        //     uint256 limitTimes;
        //     uint256 mintType;
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
                mintData.limitTimes,
                mintData.mintType,
                mintData.signCode,
                keccak256(mintData.wlSignature))
        );
    }

    function hashDigest(ICartoonMintRule.MintRule calldata mintData) public view returns (bytes32) {
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

    function verifyCondition(ICartoonMintRule.MintRule calldata mintData, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        bytes32 digest = hashDigest(mintData);
        return ecrecover(digest, v, r, s) == _SIGNER;    
    }

    function verify( ICartoonMintRule.MintRule calldata mintData, address user, bytes memory dataSignature ) public view returns (bool) {
       
        require(mintData.signCode != "","lifeform: invalid sign code!");

        bytes32 digest = hashDigest(mintData);
        require(verifySignature(digest,dataSignature),"lifeform: invalid dataSignatures! ");

        if(mintData.wlSignature.length >0 ){
            bytes32 hash = hashWhiteList(user, mintData.signCode);
            require( verifySignature(hash, mintData.wlSignature), "lifeform: invalid wlSignature! ");
        }

        return true;
    }


}
