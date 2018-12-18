pragma solidity ^0.4.25;

import './Ownable.sol';
import './ERC20.03.sol';

interface CryptoDuelI {
    function withdraw(int _referrerID, uint N) external returns (bool);
    function getReward(address _referrer, uint N) external view returns (uint256);
}

/**
 * @title Dividend Distribution Contract for AppDAO
 */
contract AppDD is ERC20, Ownable {

  CryptoDuelI source; // contract application
  bytes code;     // profit interface

  mapping (uint256 => uint256) public dividends;
  mapping (address => uint256) public ownersbal;  
  mapping (uint256 => mapping (address => bool)) public AlreadyReceived;
  uint public multiplier = 100000; // precision to ten thousandth percent (0.001%)

  event Payment(address indexed sender, uint amount);
   
  // Take profit for dividends from source contract
  function TakeProfit() external {
    uint256 N = (block.timestamp - start) / period;
    uint256 sum = source.getReward(address(this), N);
    if(sum > 0) {
        require(source.withdraw(0, N));
        dividends[N] = sum;
    }
  }

  // Link to source contract
  function Link(address _contract, bytes _code) external {
    source = CryptoDuelI(_contract);
    code = _code;
  }  

  function () public payable {
      emit Payment(msg.sender, msg.value);
  }
  
  // PayDividends to owners
  function PayDividends(uint offset, uint limit) external {
    require (address(this).balance > 0);
    require (limit <= owners.length);
    require (offset < limit);

    uint256 N = (block.timestamp - start) / period; // current - 1
    uint256 date = start + N * period - 1;
    
    require(dividends[N] > 0);
    //if (dividends[N] == 0) {
    //  dividends[N] = address(this).balance;
    //}

    uint share = 0;
    uint k = 0;
    for (k = offset; k < limit; k++) {
      if (!AlreadyReceived[N][owners[k]]) {
        share = safeMul(balanceOf(owners[k], date), multiplier);
        share = safeDiv(safeMul(share, 100), totalSupply_); // calc the percentage of the totalSupply_ (from 100%)

        share = safePerc(dividends[N], share);
        share = safeDiv(share, safeDiv(multiplier, 100));  // safeDiv(multiplier, 100) - convert to hundredths
        
        ownersbal[owners[k]] = safeAdd(ownersbal[owners[k]], share);
        AlreadyReceived[N][owners[k]] = true;
      }
    }
  }

  // PayDividends individuals to msg.sender
  function PayDividends() external {
    require (address(this).balance > 0);

    uint256 N = (block.timestamp - start) / period; // current - 1
    uint256 date = start + N * period - 1;

    require(dividends[N] > 0);
    //if (dividends[N] == 0) {
    //  dividends[N] = address(this).balance;
    //}
    
    if (!AlreadyReceived[N][msg.sender]) {      
      uint share = safeMul(balanceOf(msg.sender, date), multiplier);
      share = safeDiv(safeMul(share, 100), totalSupply_); // calc the percentage of the totalSupply_ (from 100%)

      share = safePerc(dividends[N], share);
      share = safeDiv(share, safeDiv(multiplier, 100));  // safeDiv(multiplier, 100) - convert to hundredths
        
      ownersbal[msg.sender] = safeAdd(ownersbal[msg.sender], share);
      AlreadyReceived[N][msg.sender] = true;
    }
  }

  // withdraw dividends
  function withdraw(uint _value) external {    
    require(ownersbal[msg.sender] >= _value);
    ownersbal[msg.sender] = safeSub(ownersbal[msg.sender], _value);
    msg.sender.transfer(_value);
  }

  function setMultiplier(uint _value) external onlyOwner {
    require(_value > 0);
    multiplier = _value;
  }
  
  function getMultiplier() external view returns (uint ) {
    return multiplier;
  }  
}