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

import "../lib/ERC721A.sol";
import "./Interface/ICartoon721.sol";

contract CartoonAvatar is ERC721A, Ownable, ICartoon721 {

    using Strings for uint256;

    event eAddMinter(
        address minter,
        uint256 blockNum
    );
    event eRemoveMinter(
        address minter,
        uint256 blockNum
    );


    string public _baseUri;
    string public _metatype;
  
    mapping(uint256 => ICartoon721.ExtraInfo) public _extraInfo;
    mapping(address => bool) public _minters;

    modifier onlyMinter() {
        require(_minters[msg.sender], "must call by minter");
        _;
    }

    ////////////////////////////////////////////////////////////////////////
    constructor(string memory name,string memory symbol,string memory base, string memory metatype) 
        ERC721A(name, symbol) {
        _baseUri = base;
        _metatype = metatype; 
    }

    /**
     * @dev function to grant permission to a minter
     */
    function addMinter(address minter) public onlyOwner {

        _minters[minter] = true;

        emit eAddMinter(minter,block.number);
    }
    /**
     * @dev function to remove permission to a minter
     */
    function removeMinter(address minter) public onlyOwner {

        _minters[minter] = false;

        emit eRemoveMinter(minter,block.number);
    }

    /**
     * @dev function to set the metadata file type
     */
    function setMetaType(string memory metatype) public onlyOwner{
        _metatype = metatype;
    }

    /**
     * @dev function to set a base url of the metadata
     */
    function setBaseURI(string memory uri) public onlyOwner {
        _baseUri = uri;
    }

    /**
     * @dev function to get the minted number of the address.
     */
    function mintedNumber(address addr) external override view returns(uint256) {
        return _numberMinted(addr);
    }

     /**
     * @dev function to batch transfer tokens.
     * @param from The address that will transfer tokens.
     * @param to The address that will receive the tokens.
     * @param ids The token ids to be transfered.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, bytes memory data ) external override
    {
        for (uint256 i = 0; i < ids.length; ++i) {
            safeTransferFrom(from, to,ids[i],data);
        }
        emit TransferBatch(from, to, ids);
    }
    
    /**
     * @dev function to get the metadata url by tokenId
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), _metatype)) : "";
    }

    /**
     * @dev function to get the oership info by tokenId.
     */
    function getOwnershipOf(uint256 tokenId) public view  returns (TokenOwnership  memory) {
        return _ownerships[tokenId];
    }


   
    /**
     * @dev Function to mint tokens.
     * @param to The address that will receive the minted token.
     * @param mintRule The token info to mint.
     * @param stakeErc20 The token info to mint.
     * @param stakeAmount The token info to mint.
     */
    function mint(address to, address mintRule, address stakeErc20, uint256 stakeAmount) external override  onlyMinter returns (uint256 id) 
    {
        uint256 tokenId = _currentIndex;

        ICartoon721.ExtraInfo storage sInfo = _extraInfo[_currentIndex];
        sInfo.mintRule = mintRule;
        sInfo.stakeErc20 = stakeErc20;
        sInfo.stakeAmount = stakeAmount;
        sInfo.id = _currentIndex;
        
        _safeMint(to, 1, "");

        return tokenId;
    }

    /**
     * @dev Burns a specific ERC721 token.
     * @param tokenId uint256 id of the ERC721 token to be burned.
     */
    function burn(uint256 tokenId) external override  onlyMinter
    {
        require(
            _isApprovedOrOwner(tokenId),
            "caller is not owner nor approved"
        );

        _burn(tokenId);
    }

    /**
     * @dev The function returns the list of tokens info after the token ID(pageMax*offset)
     * @param offset page index
     * @param pageMax the max count of one page
     */
     function tokensInfoByPage(uint256 offset, uint256 pageMax ) public view returns (ICartoon721.ExtraInfo [] memory infos) {

        require(pageMax>0, "invalid page size!");
        
        uint256 balance = _currentIndex;
        uint256 maxCount = 0;
        if(balance <= pageMax){
            maxCount = balance;
        }
        else{
            maxCount = pageMax;
            uint256 pages = balance/pageMax;
        
            require(pages>=offset, "invalid page size!");

            if(pages == offset){
                maxCount = balance%pageMax;
                require(maxCount > 0, "invalid page size!");
            }
        }
       
        infos = new ICartoon721.ExtraInfo[](maxCount);

        uint256 tokenId = 0;
        for(uint i=0; i<maxCount; i++){
            tokenId = offset*pageMax+i;
            infos[i] = _extraInfo[tokenId];
        }

    }

     /**
     * @dev function to get the avatar extra info by tokenId
     */
    function getExtraInfo(uint256 tokenId) external override view returns (ICartoon721.ExtraInfo memory){
        return _extraInfo[tokenId];
    }

    /**
     * @dev IERC165-supportsInterface
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev _baseURI override
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /**
     * @dev function to check the approve state 
     */
    function _isApprovedOrOwner( uint256 tokenId) internal view virtual returns (bool ) {

        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (_msgSender() == prevOwnership.addr ||
            isApprovedForAll(prevOwnership.addr, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        return isApprovedOrOwner;
    }

}