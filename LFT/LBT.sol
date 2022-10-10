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
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LifeformBoundToken is ERC721Enumerable, Ownable {
    
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    string public _baseUri =  "https://ipfs";
    string public _metatype =  ".json";

    uint256 public _mintIndex;
    bool public _publicMint;
    bool public _personality = false;

    EnumerableSet.AddressSet private _sbtContracts;

    address private _signer;
   
    constructor(
        string memory name,
        string memory symbol,
        string memory base, 
        string memory metatype,
        address signer
    ) ERC721(name, symbol) {
        _signer = signer;
        _baseUri= base;
        _metatype = metatype; 
    }

    function baseURI() internal view returns (string memory) {
        return _baseUri;
    }

    function mint(bytes memory sign) public{

         _mintIndex++;

        if( !_publicMint ){
            require(verify(msg.sender, sign), "this sign is not valid");
        }

        require(balanceOf(msg.sender) == 0, "this address has a bound token!");
      
        _safeMint(msg.sender, _mintIndex);
       
    }

    function burn(uint256 tokenId) public{
        _burn(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        if(!_personality){
            return bytes(_baseUri).length > 0 ? string(abi.encodePacked(_baseUri, symbol(), _metatype)) : "";
        }
        else{
            return bytes(_baseUri).length > 0 ? string(abi.encodePacked(_baseUri, tokenId.toString(), _metatype)) : "";
        }
    }

    //check the owner for a tokenid
    function isOwner(uint256 tokenId, address owner) public view returns(bool isowner) {
        address tokenOwner = ownerOf(tokenId);
        isowner = (tokenOwner == owner);
    }

    //get the bounded token id
    function getBoundId(address owner) public view returns(uint256 tokenId) {
        return tokenOfOwnerByIndex(owner,0);
    }

    //get the mint status for an address
    function getMintState(bytes memory sign) public view returns(uint8 state) {
        if(balanceOf(msg.sender) > 0){
            return 2;
        }
        else{
            if(_publicMint){
                return 1;
            }
            else{
                if(verify(msg.sender, sign)){
                    return 1;
                }
                else{
                    return 0;
                }
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    function updateBaseUri(string memory baseUri) public onlyOwner {
        _baseUri = baseUri;
    }
    
    //public mint switch
    function updatePublicMint(bool enable) public onlyOwner {
        _publicMint = enable;
    }

    //update the signature signer
    function updateSigner(address signer) public onlyOwner {
        _signer = signer;
    }

    //public personality token switch
    function updatePersonality(bool enable) public onlyOwner {
        _personality = enable;
    }

    //add a sbt contract to white list
    function addSBTContract(address sbtContract) public onlyOwner {
        if(!_sbtContracts.contains(sbtContract)){
            _sbtContracts.add(sbtContract);
        }
    }

    //remove a sbt contract from white list
    function removeSBTContract(address sbtContract) public onlyOwner {
        if(_sbtContracts.contains(sbtContract)){
            _sbtContracts.remove(sbtContract);
        }
    }

    //get sbt contract in  white list
    function getSBTContracts() public view returns ( address[] memory ) {
        return _sbtContracts.values();
    }

    //verify the mint permissions
    function verify(address user, bytes memory signatures) public view returns (bool) {

        //for sbtContract verify
        address sbtContract;
        for(uint i=0; i< _sbtContracts.length(); i++){
            sbtContract = _sbtContracts.at(i);
            if(sbtContract != address(0x0)){
                if((IERC721)(sbtContract).balanceOf(user)>0){
                    return true;
                }
            }
        }

        if(signatures.length==0){
            return false;
        }
      
        //for whitelist verify
        bytes32 message = keccak256(abi.encodePacked(user, address(this)));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
        address[] memory signList = recoverAddresses(hash, signatures);
        return signList[0] == _signer;
    }

    function recoverAddresses(bytes32 _hash, bytes memory _signatures) internal pure returns (address[] memory addresses) {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint count = _countSignatures(_signatures);
        addresses = new address[](count);
        for (uint i = 0; i < count; i++) {
            (v, r, s) = _parseSignature(_signatures, i);
            addresses[i] = ecrecover(_hash, v, r, s);
        }
    }
    
    function _parseSignature(bytes memory _signatures, uint _pos) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        uint offset = _pos * 65;
        assembly {
            r := mload(add(_signatures, add(32, offset)))
            s := mload(add(_signatures, add(64, offset)))
            v := and(mload(add(_signatures, add(65, offset))), 0xff)
        }

        if (v < 27) v += 27;

        require(v == 27 || v == 28);
    }
    
    function _countSignatures(bytes memory _signatures) internal pure returns (uint) {
        return _signatures.length % 65 == 0 ? _signatures.length / 65 : 0;
    }

    /// @notice These functions was disabled to make the token Soulbound. Calling it will revert
    //
    function approve(address to, uint256 tokenId) public virtual override {
        to; tokenId;
        require(false, "soulbound!");
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        owner;operator;
        require(false, "soulbound!");
        return false;
    }

    function getApproved(uint256 tokenId) public pure override returns (address) {
        tokenId;
        require(false, "soulbound!");
        return  address(0);
    }

    function setApprovalForAll(address operator, bool approved) public pure override {
        operator;approved;
        require(false, "soulbound!");
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        from;to;tokenId;
        require(false, "soulbound!");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        from;to;tokenId;
        require(false, "soulbound!");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
       from;to;tokenId;_data;
       require(false, "soulbound!");
    }

}