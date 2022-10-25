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
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Interface/IAdorn721.sol";
import "./Interface/IAdorn1155.sol";

contract StoreFactory is Ownable,ReentrancyGuard{

    event Adorn721Mint(
        uint256 lastId,
        uint256 amount,
        address target,
        address author,
        address nftContract,
        uint256 createdTime,
        uint256 blockNum
    );

    event Adorn721Burn(
        uint256 id,
        address who,
        address nftContract,
        uint256 createdTime,
        uint256 blockNum
    );

    event Adorn1155Mint(
        uint256[] ids,
        uint256[] amounts,
        address target,
        address author,
        address nftContract,
        uint256 createdTime,
        uint256 blockNum
    );

    event Adorn1155Burn(
        uint256[] ids,
        uint256[] amounts,
        address who,
        address nftContract,
        uint256 createdTime,
        uint256 blockNum
    );

   struct MintInfo {
        address costErc20;    
        address collect;      //for 721 or 1155
        uint256[] ids;        //just use for 1155
        uint256[] prices; 
        uint256[] amounts;     
        bytes32 signCode; 
    }

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    using ECDSA for bytes32;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    using SafeERC20 for IERC20;
    using Address for address;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    //type hash
    bytes32 public constant TYPE_HASH = keccak256(
        "MintInfo(address costErc20,address collect,uint256[] ids,uint256[] prices,uint256[] amounts,bytes32 signCode)"
    );

    address private SIGNER;
    EnumerableSet.Bytes32Set private _signCodes;

    mapping(address => bool) public _IAMs;
    bool public _isUserStart = false;
    address public  _teamWallet;

    constructor(address teamWallet) {
        _teamWallet = teamWallet;
        addIAM(msg.sender);

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("StoreFactory"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );

        SIGNER = msg.sender;
    }

    function updateTeamWallet(address teamWallet ) public onlyOwner
    {
        _teamWallet = teamWallet;
    }

    function setUserStart(bool start) public onlyOwner {
        _isUserStart = start;
    }

    function addIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = true;
    }

    function removeIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = false;
    }

    // only function for creating additional rewards from dust
    function seize(IERC20 asset, address teamWallet) public onlyOwner {
        uint256 balance = asset.balanceOf(address(this));
        asset.safeTransfer(teamWallet, balance);
    }
    
   function updateSigner( address signer) public onlyOwner {
        SIGNER = signer;
    }

    function getChainId( ) public view returns (uint256) {
        return block.chainid;
    }

    function mintAdorn721(address target, MintInfo calldata condition, bytes memory dataSignature) external nonReentrant
    {
        address origin = msg.sender;
        bool isIAM = _IAMs[msg.sender];
        if(isIAM == false){
            require(!origin.isContract(), "lifeform: call to non-contract");
        }
        
        require(  _isUserStart || isIAM  , "lifeform: can't mint" );

        if( _isUserStart ){

            check(condition, dataSignature);

            _signCodes.add(condition.signCode);
        }

        uint256 lastId = (IAdorn721)(condition.collect).mint(target, condition.amounts[0]);

        emit Adorn721Mint(
                lastId,
                condition.amounts[0],
                target,
                msg.sender,
                condition.collect,
                block.timestamp,
                block.number
            );
    } 

    function burnAdorn721(address collect, uint256 tokenId) external nonReentrant {

        (IAdorn721)(collect).burn(tokenId);

        emit Adorn721Burn(
                tokenId,
                msg.sender,
                collect,
                block.timestamp,
                block.number
            );
    }

    function mintAdorn1155( address target, MintInfo calldata condition, bytes memory dataSignature) external nonReentrant
    {
       address origin = msg.sender;
       bool isIAM =_IAMs[msg.sender];
       if( isIAM == false){
           require(!origin.isContract(), "lifeform: call to non-contract");
       }

       require( _isUserStart || isIAM  , "lifeform: can't mint" );

       if( _isUserStart ){

           check(condition, dataSignature);
       
           _signCodes.add(condition.signCode);
       }

       uint256 cost = 0;
       for(uint256 i=0; i<condition.ids.length; i++){
           cost = cost.add(condition.prices[i].mul(condition.amounts[i]));
       }

       IERC20 costErc20 = (IERC20)(condition.costErc20);
       costErc20.safeTransferFrom(msg.sender, _teamWallet, cost );
       
       (IAdorn1155)(condition.collect).mintBatch(target, condition.ids, condition.amounts, "");

       emit Adorn1155Mint(
               condition.ids,
               condition.amounts,
               target,
               msg.sender,
               condition.collect,
               block.timestamp,
               block.number
           );
    } 

    function burnAdorn1155(address collect, uint256[] memory tokenIds, uint256[] memory amounts) external nonReentrant {

         (IAdorn1155)(collect).burnBatch(msg.sender, tokenIds, amounts);

         emit Adorn1155Burn(
                tokenIds,
                amounts,
                msg.sender,
                collect,
                block.timestamp,
                block.number
            );
    }


    function isExistSignCode(bytes32 signCode) view public returns(bool) {
        return _signCodes.contains(signCode);
    }

    function check( MintInfo calldata condition,bytes memory dataSignature ) public view {
        require(
        condition.ids.length == condition.prices.length &&
        condition.prices.length == condition.amounts.length , "invalid data!");

        require(!isExistSignCode(condition.signCode),"invalid signCode!");

        require(verify(condition,  dataSignature), "this sign is not valid");

    } 

    function hashCondition(MintInfo calldata condition) public pure returns (bytes32) {

    // struct BatchItemBuyData {
    //     address costErc20;    
    //     address collect;    //for 721 or 1155
    //     uint256[] ids;       //just use for 1155
    //     uint256[] prices; 
    //     uint256[] amounts;     
    //     bytes32 signCode; 
    // }

        return keccak256(
            abi.encode(
                TYPE_HASH,
                condition.costErc20,
                condition.collect,
                keccak256(abi.encodePacked(condition.ids)),
                keccak256(abi.encodePacked(condition.prices)),
                keccak256(abi.encodePacked(condition.amounts)),
                condition.signCode)
        );
    }

    function hashDigest(MintInfo calldata condition) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hashCondition(condition)
        ));
    }

    function verifySignature(bytes32 hash, bytes memory  signature) public view returns (bool) {
        //hash must be a soliditySha3 with accounts.sign
        return hash.recover(signature) == SIGNER;
    }

    function verifyCondition(MintInfo calldata condition, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        bytes32 digest = hashDigest(condition);
        return ecrecover(digest, v, r, s) == SIGNER;    
    }

    function verify(  MintInfo calldata condition, bytes memory dataSignature ) public view returns (bool) {
       
        require(condition.signCode != "","invalid sign code!");

        bytes32 digest = hashDigest(condition);
        require(verifySignature(digest,dataSignature)," invalid dataSignatures! ");

        return true;
    }
}
