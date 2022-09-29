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
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
// import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Interface/IAdorn721.sol";
import "./Interface/IAdorn1155.sol";
import "./Interface/IWETH.sol";

contract StoreFactory is Ownable,ReentrancyGuard{

    event Adorn721Mint(
        uint256 lastId,
        uint256 amount,
        uint256 price,
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
        uint256[] prices,
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
        bytes wlSignature;    //enable white
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
    using SafeMath for uint256;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    //type hash
    bytes32 public constant TYPE_HASH = keccak256(
        "MintInfo(address costErc20,address collect,uint256[] ids,uint256[] prices,uint256[] amounts,bytes32 signCode,bytes wlSignature)"
    );

    address private SIGNER;
    EnumerableSet.Bytes32Set private _signCodes;

    mapping(address => bool) public _IAMs;
    bool public _isUserStart = false;
    bool public _onceSignCode = true;
    address public  _teamWallet;
    address public  _WETH;

    constructor(address teamWallet, address WETH) {

        _teamWallet = teamWallet;
        _WETH = WETH;

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

    function updateTeamWallet(address teamWallet ) public onlyOwner{
        _teamWallet = teamWallet;
    }

    function updateWETH(address WETH ) public onlyOwner{
         _WETH = WETH;
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

    function mintAdornWithETH(address target, uint64 ercType, MintInfo calldata condition, bytes memory dataSignature) public payable
    {
        require(condition.costErc20 == address(0x0), "invalid mint method!" );
        uint256 cost = 0;
        for(uint256 i=0; i<condition.ids.length; i++){
            cost = cost.add(condition.prices[i].mul(condition.amounts[i]));
        }

        if(cost>0){
            require(msg.value >= cost, "invalid cost amount! ");
            IWETH(_WETH).deposit{value: msg.value}();
            IERC20(_WETH).safeTransfer(_teamWallet, msg.value);
        }

        if(ercType == 1155 ){
            _mintAdorn1155(target,condition,dataSignature);
        }
        else if(ercType == 721 ){
            _mintAdorn721(target,condition,dataSignature);
        }
        else{
            require(false, "invalid mint ercType!" );
        }
    }

    //mint 
    function mintAdorn( address target, uint64  ercType, MintInfo calldata condition, bytes memory dataSignature) external 
    {
        require(condition.costErc20 != address(0x0), "invalid mint currency type !" );

        uint256 cost = 0;
        for(uint256 i=0; i<condition.ids.length; i++){
            cost = cost.add(condition.prices[i].mul(condition.amounts[i]));
        }

        if(cost>0){      
            IERC20 costErc20 = (IERC20)(condition.costErc20);
            costErc20.safeTransferFrom(msg.sender, _teamWallet, cost );
        }

        if(ercType == 1155 ){
            _mintAdorn1155(target,condition,dataSignature);
        }
        else if(ercType == 721 ){
            _mintAdorn721(target,condition,dataSignature);
        }
        else{
            require(false, "invalid mint ercType!" );
        }
      
    } 

    //mint the 721 asset
    function _mintAdorn721(address target, MintInfo calldata condition, bytes memory dataSignature) internal
    {
        address origin = msg.sender;
        if(_IAMs[msg.sender] == false){
            require(!origin.isContract(), "lifeform: call to non-contract");
        }
        
        require(  _isUserStart || _IAMs[msg.sender]  , "lifeform: can't mint" );

        if( _isUserStart ){
            check(condition, dataSignature);
            _signCodes.add(condition.signCode);
        }

        uint256 lastId = (IAdorn721)(condition.collect).mint(target, condition.amounts[0]);

        emit Adorn721Mint(
                lastId,
                condition.amounts[0],
                condition.prices[0],
                target,
                msg.sender,
                condition.collect,
                block.timestamp,
                block.number
            );
    } 

    //destory a 721 asset
    function burnAdorn721(address collect, uint256 tokenId) external {

        (IAdorn721)(collect).burn(tokenId);

        emit Adorn721Burn(
                tokenId,
                msg.sender,
                collect,
                block.timestamp,
                block.number
            );
    }

    //mint the 1155 asset
    function _mintAdorn1155( address target, MintInfo calldata condition, bytes memory dataSignature) internal 
    {

        address origin = msg.sender;
        if(_IAMs[msg.sender] == false){
            require(!origin.isContract(), "lifeform: call to non-contract");
        }

        require( _isUserStart || _IAMs[msg.sender]  , "lifeform: can't mint" );

        if( _isUserStart ){
            check(condition, dataSignature);
            _signCodes.add(condition.signCode);
        }
        
        (IAdorn1155)(condition.collect).mintBatch(target, condition.ids, condition.amounts, "");

        emit Adorn1155Mint(
                condition.ids,
                condition.amounts,
                condition.prices,
                target,
                msg.sender,
                condition.collect,
                block.timestamp,
                block.number
            );
    } 

    //batch destory the 1155 assets
    function burnAdorn1155(address collect, uint256[] memory tokenIds, uint256[] memory amounts) external{

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

    //check the state of a signCode
    function isExistSignCode(bytes32 signCode) view public returns(bool) {
        return _signCodes.contains(signCode);
    }

    //MintInfo data check
    function check( MintInfo calldata condition,bytes memory dataSignature ) public view {
        require(
        condition.ids.length == condition.prices.length &&
        condition.prices.length == condition.amounts.length , "invalid data!");

        if(_onceSignCode){
            require(!isExistSignCode(condition.signCode),"invalid signCode!");
        }

        require(verify(condition, msg.sender, dataSignature), "this sign is not valid");

    } 

    //generate the whitelist user hash
    function hashWhiteList( address user, bytes32 signCode ) public pure returns (bytes32) {

        bytes32 message = keccak256(abi.encodePacked(user, signCode));
        // hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return message.toEthSignedMessageHash();
    }

    //generate the MintInfo hash
    function hashCondition(MintInfo calldata condition) public pure returns (bytes32) {

    // struct BatchItemBuyData {
    //     address costErc20;    
    //     address collect;     //for 721 or 1155
    //     uint256[] ids;       //just use for 1155
    //     uint256[] prices; 
    //     uint256[] amounts;     
    //     bytes32 signCode; 
    //     bytes wlSignature;   //enable white
    // }

        return keccak256(
            abi.encode(
                TYPE_HASH,
                condition.costErc20,
                condition.collect,
                keccak256(abi.encodePacked(condition.ids)),
                keccak256(abi.encodePacked(condition.prices)),
                keccak256(abi.encodePacked(condition.amounts)),
                condition.signCode,
                keccak256(condition.wlSignature))
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

    function verify( MintInfo calldata condition, address user, bytes memory dataSignature ) public view returns (bool) {
       
        require(condition.signCode != "","invalid sign code!");

        bytes32 digest = hashDigest(condition);
        require(verifySignature(digest,dataSignature)," invalid dataSignatures! ");

        if(condition.wlSignature.length >0 ){
            bytes32 hash = hashWhiteList(user, condition.signCode);
            require( verifySignature(hash, condition.wlSignature), "invalid wlSignature! ");
        }

        return true;
    }

}