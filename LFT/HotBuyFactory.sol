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

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./Interface/IAdorn721.sol";
import "./Interface/IAdorn1155.sol";
import "./Interface/IWETH.sol";

contract HotBuyFactory is Ownable,ReentrancyGuard{

    using ECDSA for bytes32;
    using Address for address;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    //event mint
    event eMint(
        address user,
        uint256 costAmount,
        uint256 historyCount,
        uint256 stageSoldAmount,
        uint256 mintCount,
        uint256 tokenId
    );

    struct ProjcetInfo{
        address costErc20;
        uint256 saleAmount;
        uint256 withdrawAmount;
        bool isUserStart;
    }

    struct Condition {

        uint256 price;          //nft per cost erc20
        uint256 startTime;      //the start time
        uint256 endTime;        //the end time
        uint256 limitCount;     //a quota
        uint256 maxSoldAmount;  //the max sold amount
        bytes32 signCode;       //signCode
        uint256 tokenId;        //the token id, if erctype is 721,the tokenid is zero
        address nftContract;    //the hotbuy nft contract address
        bytes wlSignature;      //enable white
    }

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

    //type hash
    bytes32 public constant TYPE_HASH = keccak256(
        "Condition(uint256 price,uint256 startTime,uint256 endTime,uint256 limitCount,uint256 maxSoldAmount,bytes32 signCode,uint256 tokenId,address nftContract,bytes wlSignature)"
    );

    // launchpad nft project info
    mapping(address => ProjcetInfo ) public _projcetInfo; //nft contract->ProjcetInfo

    // super minters
    mapping(address => EnumerableSet.AddressSet ) private _IAMs; //nft contract->IAMs

    // tags show address can join in open sale
    mapping(address =>EnumerableSet.Bytes32Set) private _721SignCodes;//erc721->signCode

     // tags show address can join in open sale
    mapping(address =>mapping (uint256 =>EnumerableSet.Bytes32Set)) private _1155SignCodes;//erc1155->signCode

    // the user get count for 721
    mapping(address =>EnumerableMap.AddressToUintMap ) private _721HistoryCount;//erc721->user buyCount

    // the user get count for 1155
    mapping(address =>mapping (uint256 =>EnumerableMap.AddressToUintMap )) private _1155HistoryCount;//erc1155->user buyCount

    // the 721 had sold count
    mapping(address => uint256 ) public _721SoldCount; //erc721->sold count

    // the 1155 had sold count
    mapping(address => mapping (uint256 => uint256) ) public _1155SoldCount; //erc1155->sold count

    address private _SIGNER;

    address public  _WETH;

    constructor(address WETH) {

        _WETH = WETH;
        _SIGNER = msg.sender;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712DOMAIN_TYPEHASH,
                keccak256("HotBuyFactory"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }

    function setProject(address nftContract, address costErc20) public onlyOwner{
        _projcetInfo[nftContract].costErc20 = costErc20;
    }

    function setUserStart(address nftContract, bool start) public onlyOwner {
        _projcetInfo[nftContract].isUserStart = start;
    }

    function addIAM(address nftContract,address minter) public onlyOwner {
        _IAMs[nftContract].add(minter);
    }

    function removeIAM(address nftContract,address minter) public onlyOwner {
        _IAMs[nftContract].remove(minter);
    }

    function isValid721SignCode(address nftContract,bytes32 signCode) view public returns(bool) {
        return !_721SignCodes[nftContract].contains(signCode);
    }

    function isValid1155SignCode(address nftContract,uint256 tokenId, bytes32 signCode) view public returns(bool) {
        return !_1155SignCodes[nftContract][tokenId].contains(signCode);
    }

    function isIAM(address nftContract,address minter) view public returns(bool) {
        return _IAMs[nftContract].contains(minter);
    }

    function getChainId() view public returns(uint256) {
        return block.chainid;
    }

    function getHistoryCount(address nftContract, uint256 tokenId, address user) view public returns(uint256) {
        bool have;
        uint256 historyCount;
        (have,historyCount) = _721HistoryCount[nftContract].tryGet(user);
        if(have){
            return historyCount;
        }

        (have,historyCount) = _1155HistoryCount[nftContract][tokenId].tryGet(user);
        return historyCount;
    }

    function getSoldCount(address nftContract, uint256 tokenId) view public returns(uint256) {
        uint256 soldCount = _721SoldCount[nftContract];
        if(soldCount!=0){
            return soldCount;
        }
        soldCount = _1155SoldCount[nftContract][tokenId];
        return soldCount;
    }

    // get ProjcetInfo
    function getProjectInfo(address nftContract) view public returns( ProjcetInfo memory ) {
        return _projcetInfo[nftContract];
    }

    function mintAdornWithETH(uint64  ercType,uint256 mintCount,  Condition calldata condition, bytes memory dataSignature) public payable nonReentrant
    {
        address nftContract = condition.nftContract;
        require(_projcetInfo[nftContract].costErc20 == address(0x0), "invalid mint method!" );

        uint256 costAmount = condition.price.mul(mintCount);
        if(costAmount > 0){

            require(msg.value >= costAmount, "invalid cost amount! ");

            IWETH(_WETH).deposit{value: msg.value}();
            IERC20(_WETH).safeTransfer(address(this), msg.value);

            _projcetInfo[nftContract].saleAmount+=costAmount;
        }
      
        if(ercType == 1155 ){
            _mint1155(nftContract,mintCount,condition,dataSignature);
        }
        else if(ercType == 721 ){
            _mint721(nftContract,mintCount,condition,dataSignature);
        }
        else{
            require(false, "invalid mint ercType!" );
        }
            
    }

    function mintAdorn(uint64  ercType,uint256 mintCount, Condition calldata condition, bytes memory dataSignature )  public nonReentrant {

        address nftContract = condition.nftContract;
        require(_projcetInfo[nftContract].costErc20 != address(0x0),"invalid cost token address!");

        uint256 costAmount = condition.price.mul(mintCount);
        if(costAmount > 0){

            IERC20 costErc20 =  IERC20(_projcetInfo[nftContract].costErc20);
            uint256 balanceBefore = costErc20.balanceOf(address(this));
            costErc20.safeTransferFrom(msg.sender, address(this), costAmount);
            uint256 balanceAfter = costErc20.balanceOf(address(this));

            _projcetInfo[nftContract].saleAmount+=balanceAfter.sub(balanceBefore);
            
        }

        if(ercType == 1155 ){
            _mint1155(nftContract,mintCount,condition,dataSignature);
        }
        else if(ercType == 721 ){
            _mint721(nftContract,mintCount,condition,dataSignature);
        }
        else{
            require(false, "invalid mint ercType!" );
        }

    } 


    // mint721 asset
    function _mint721(address nftContract, uint256 mintCount, Condition calldata condition, bytes memory dataSignature )  internal {

        require(mintCount>0, "invalid mint count!");

        bool exist = _IAMs[nftContract].contains(msg.sender);
        if(!exist){
            require(!msg.sender.isContract(), "call to non-contract");
        }
        require(_projcetInfo[nftContract].isUserStart || exist  , "can't mint" );

        require( block.timestamp >= condition.startTime && block.timestamp < condition.endTime, "out date" );

        bool have ;
        uint256 historyCount;
        (have,historyCount)= _721HistoryCount[nftContract].tryGet(msg.sender);

        if(!exist){

            require(verify(condition, msg.sender, dataSignature), "this sign is not valid");

            uint256 count = historyCount + mintCount;
            require(count <= condition.limitCount,"sale count is max ");

            //once signCode
            require(isValid721SignCode(nftContract,condition.signCode),"invalid signCode!");
        }

        uint256 costAmount = condition.price.mul(mintCount);
        if(costAmount > 0){

            historyCount += mintCount;

            _721HistoryCount[nftContract].set(msg.sender,historyCount);
            _721SoldCount[nftContract] += mintCount;

        }

        IAdorn721(nftContract).mint(msg.sender,mintCount);

        _721SignCodes[nftContract].add(condition.signCode);

        emit eMint(
                msg.sender,
                costAmount,
                historyCount,
                _721SoldCount[nftContract],
                mintCount,
                0
            );
    } 


    // mint1155 asset
    function _mint1155(address nftContract, uint256 mintCount, Condition calldata condition, bytes memory dataSignature )  internal {

        require(mintCount>0, "invalid mint count!");

        bool exist = _IAMs[nftContract].contains(msg.sender);
        if(!exist){
            require(!msg.sender.isContract(), "call to non-contract");
        }
        require( _projcetInfo[nftContract].isUserStart || exist  , "can't mint" );

        require( block.timestamp >= condition.startTime && block.timestamp < condition.endTime, "out date" );

        uint256 tokenId = condition.tokenId;

        bool have ;
        uint256 historyCount;
        (have,historyCount)= _1155HistoryCount[nftContract][tokenId].tryGet(msg.sender);


        if(!exist){

            require(verify(condition, msg.sender, dataSignature), "this sign is not valid");

            uint256 count = historyCount + mintCount;
            require(count <= condition.limitCount,"sale count is max ");

            //once signCode
            require(isValid1155SignCode(nftContract,tokenId,condition.signCode),"invalid signCode!");
        }

        uint256 costAmount = condition.price.mul(mintCount);
        if(costAmount > 0){

            historyCount += mintCount;

            _1155HistoryCount[nftContract][tokenId].set(msg.sender,historyCount);
            _1155SoldCount[nftContract][tokenId] += mintCount;

        }

        IAdorn1155(nftContract).mint(msg.sender,tokenId,mintCount,"");

        _1155SignCodes[nftContract][tokenId].add(condition.signCode);

        emit eMint(
                msg.sender,
                costAmount,
                historyCount,
                _1155SoldCount[nftContract][tokenId],
                mintCount,
                tokenId
            );
    } 

    function withdrawETH(address wallet) external onlyOwner {
        payable(wallet).transfer(address(this).balance);
    }

    function withdrawMoney(address nftContract, address wallet) external onlyOwner {
        IERC20 costErc20 =  IERC20(_projcetInfo[nftContract].costErc20);
        uint256 amount = _projcetInfo[nftContract].saleAmount.sub(_projcetInfo[nftContract].withdrawAmount);
        costErc20.safeTransfer(wallet, amount);
        _projcetInfo[nftContract].withdrawAmount += amount;
    }

    function urgencyWithdraw(address erc20, address wallet) external onlyOwner {
        IERC20(erc20).safeTransfer(wallet, IERC20(erc20).balanceOf(address(this)));
    }

    function updateSigner( address signer) external onlyOwner {
        _SIGNER = signer;
    }

    function hashCondition(Condition calldata condition) public pure returns (bytes32) {

        // struct Condition {
        //     uint256 price;          //nft per cost erc20
        //     uint256 startTime;      //the start time
        //     uint256 endTime;        //the end time
        //     uint256 limitCount;     //a quota
        //     uint256 maxSoldAmount;  //the max sold amount
        //     bytes32 signCode;       //signCode
        //     uint256 tokenId;        //the token id, if erctype is 721,the tokenid is zero
        //     address nftContract;    //the hotbuy nft contract address
        //     bytes wlSignature;      //enable white
        // }

        return keccak256(
            abi.encode(
                TYPE_HASH,
                condition.price,
                condition.startTime,
                condition.endTime,
                condition.limitCount,
                condition.maxSoldAmount,
                condition.signCode,
                condition.tokenId,
                condition.nftContract,
                keccak256(condition.wlSignature))
        );
    }

    function hashWhiteList( address user, bytes32 signCode ) public pure returns (bytes32) {

        bytes32 message = keccak256(abi.encodePacked(user, signCode));
        // hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        return message.toEthSignedMessageHash();
    }

    function hashDigest(Condition calldata condition) public view returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hashCondition(condition)
        ));
    }

    function verifySignature(bytes32 hash, bytes memory  signature) public view returns (bool) {
        //hash must be a soliditySha3 with accounts.sign
        return hash.recover(signature) == _SIGNER;
    }

    function verifyCondition(Condition calldata condition, uint8 v, bytes32 r, bytes32 s) public view returns (bool) {
        bytes32 digest = hashDigest(condition);
        return ecrecover(digest, v, r, s) == _SIGNER;    
    }

    function verify(  Condition calldata condition, address user, bytes memory dataSignature ) public view returns (bool) {
       
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
