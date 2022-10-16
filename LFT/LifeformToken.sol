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
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract LifeformToken is IERC20, Ownable {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // for minters
    mapping (address => bool) public _minters;

    //token base data
    uint256 internal _totalSupply;
    mapping(address => uint256) public _balances;
    mapping (address => mapping (address => uint256)) public _allowances;

    //
    bool public _openTransfer = false;
    
    uint8 public constant decimals = 18;
    string public constant name = "LIFEFORM";

    uint256 public  immutable maxSupply;
    string public  symbol;


    /**
    * @dev set the token transfer switch
    */
    function enableOpenTransfer() public onlyOwner  
    {
        _openTransfer = true;
    }

    constructor (
    string memory _symbol, 
    uint256 _maxSupply
    ) {
        symbol = _symbol;
        maxSupply = _maxSupply * (10**18);
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param spender The address which will spend the funds.
    * @param amount The amount of tokens to be spent.
    */
    function approve(address spender, uint256 amount) external override
    returns (bool) 
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
    * @dev Function to check the amount of tokens than an owner _allowed to a spender.
    * @param owner address The address which owns the funds.
    * @param spender address The address which will spend the funds.
    * @return A uint256 specifying the amount of tokens still available for the spender.
    */
    function allowance(address owner, address spender) external view override
    returns (uint256) 
    {
        return _allowances[owner][spender];
    }

    /// @notice New ERC20 function
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /// @notice New ERC20 function
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below tube"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the tube address");
        require(spender != address(0), "ERC20: approve to the tube address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param owner The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function balanceOf(address owner) external  view override
    returns (uint256) 
    {
        return _balances[owner];
    }

    /**
    * @dev return the token total supply
    */
    function totalSupply() external view override
    returns (uint256) 
    {
        return _totalSupply;
    }

    /**
    * @dev for mint function
    */
    function mint(address account, uint256 amount) external returns (bool){
        
        require(account != address(0), "ERC20: mint to the zero address");
        require(_minters[msg.sender], "!minter");

        uint256 newMintSupply = _totalSupply.add(amount);
        require( newMintSupply <= maxSupply,"supply is max!");
      
        _totalSupply = newMintSupply;
        _balances[account] = _balances[account].add(amount);

        emit Transfer(address(0), account, amount);

        return true;
    }


    function addMinter(address minter) public onlyOwner 
    {
        _minters[minter] = true;
    }
    
    function removeMinter(address minter) public onlyOwner 
    {
        _minters[minter] = false;
    }

    /**
    * @dev transfer token for a specified address
    * @param to The address to transfer to.
    * @param value The amount to be transferred.
    */
   function transfer(address to, uint256 value) external override
   returns (bool)  
   {
        return _transfer(msg.sender,to,value);
    }

    /**
    * @dev Transfer tokens from one address to another
    * @param from address The address which you want to send tokens from
    * @param to address The address which you want to transfer to
    * @param value uint256 the amount of tokens to be transferred
    */
    function transferFrom(address from, address to, uint256 value) external override
    returns (bool) 
    {
        uint256 allow = _allowances[from][msg.sender];
        _allowances[from][msg.sender] = allow.sub(value);
        
        return _transfer(from,to,value);
    }

 

    /**
    * @dev 
    * @param from address The address which you want to send tokens from
    * @param to address The address which you want to transfer to
    * @param value uint256s the amount of tokens to be transferred
    */
    function _transfer(address from, address to, uint256 value) internal 
    returns (bool) 
    {
        // :)
        require(_openTransfer || from == owner(), "transfer closed");

        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);

        emit Transfer(from, to, value);
    

        return true;
    }

     fallback() external payable {}

}