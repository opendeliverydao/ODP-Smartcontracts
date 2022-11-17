// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./TokenSaleAllocation.sol";

contract TokenSaleWhitelistCliffVesting is Pausable, AccessControl,TokenAllocation  {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 public startTimestamp;
    uint256 public endTimestamp;
    event StartSales(uint256 indexed timestamp);
    event EndSales(uint256 indexed timestamp);


    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    IERC20 public immutable paymentToken;

    event Sent(address indexed payee, uint256 amount, uint256 balance);
    event Received(address indexed payer,uint256 amount);
    event ReceivedErc20(address indexed payer, uint256 amount);


    IERC20 public tokenAddress;
    address public sellerAddress;
    address public taxAddress;
    uint256 public currentErc20Price;
    bool public useWhitelist;
    uint256 public minTokenAmount;
    uint256 public maxTokenAmount;

    uint256 public tokenSold;


    mapping(address => bool) public isWhitelisted;


    constructor(
      address _tokenAddress,
      address _sellerAddress, 
      address _taxAddress,
      IERC20 _payment_token,
      uint256 _currentErc20Price,
      uint256 _startTs,
      uint256 _endTs,
      uint256[] memory _tokenAllocation
      ) 
    TokenAllocation(
      _sellerAddress,
      IERC20(_tokenAddress),
      _tokenAllocation[2],
      _tokenAllocation[3],
      _tokenAllocation[4]
    )
     { 
        require(_sellerAddress != address(0) && _sellerAddress != address(this));
        require(_tokenAddress != address(0) && _tokenAddress != address(this));

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        minTokenAmount=_tokenAllocation[0];
        maxTokenAmount=_tokenAllocation[1];
        tokenAddress = IERC20(_tokenAddress);
        sellerAddress = _sellerAddress;
        currentErc20Price = _currentErc20Price;
        startTimestamp=_startTs;
        _setIcoTimestamp(_endTs);
        emit StartSales(_startTs);
        endTimestamp=_endTs;
        paymentToken=_payment_token;
        useWhitelist=false;
        taxAddress = _taxAddress;
        
    }


    function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
    }


    function purchaseTokenWithErc20(uint256 _quantity) public payable whenNotPaused afterStartSales beforeEndSales {
        require(_quantity >= minTokenAmount, "Sale: amount less than min");
        require(_quantity <= maxTokenAmount, "Sale: amount greater than max");
        uint256 sellerBalance=(IERC20(tokenAddress)).balanceOf(sellerAddress);
        require(
          _getUserTotalTokens(msg.sender) + _quantity <= maxTokenAmount,
          "Sale: total greater than max"
        );
        require(
          tokenSold + _quantity <= sellerBalance,
          "Sale: total TOKEN on sale reached"
        );

        require((!useWhitelist || isWhitelisted[msg.sender]), "Wallet is not whitelisted");
        require(_quantity >= 1);
        require(currentErc20Price>0);

        uint256 totalPayment=currentErc20Price*(_quantity/1e18);
        uint256 taxPay= (totalPayment/100)*2;
        uint256 sellerPayment=totalPayment-taxPay;

        paymentToken.transferFrom(msg.sender, sellerAddress, sellerPayment);
        paymentToken.transferFrom(msg.sender, taxAddress, taxPay);

        emit ReceivedErc20(msg.sender, currentErc20Price*(_quantity/1e18));
        tokenSold += _quantity;
        _updateUserTokenAllocation(msg.sender, _quantity);
    }

    function sendTo(address _payee, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_payee != address(0) && _payee != address(this));
        require(_amount > 0 && _amount <= address(this).balance);
        payable(_payee).transfer(_amount);
        emit Sent(_payee, _amount, address(this).balance);
    }    
 

    function setCurrentErc20Price(uint256 _currentErc20Price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_currentErc20Price > 0);
        currentErc20Price = _currentErc20Price;
    } 


          function setUseWhitelist(bool _useWhitelist)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    useWhitelist=_useWhitelist;
  }

      function addToWhitelist(address[] memory _buyers)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    for (uint256 i = 0; i < _buyers.length; i++) {
      isWhitelisted[_buyers[i]] = true;
    }
  }

  function removeFromWhitelist(address[] memory _buyers)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    for (uint256 i = 0; i < _buyers.length; i++) {
      isWhitelisted[_buyers[i]] = false;
    }
  }   

    function setStartTimestamp(uint256 _startTimestamp)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    startTimestamp=_startTimestamp;
    emit StartSales(_startTimestamp);
  }

      function setEndTimestamp(uint256 _endTimestamp)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    endTimestamp=_endTimestamp;
    emit EndSales(_endTimestamp);
    _setIcoTimestamp(_endTimestamp);
  }

     modifier beforeStartSales() {
    require(
      // solhint-disable-next-line not-rely-on-time
      block.timestamp < startTimestamp,
      "Unavailable after sales start event"
    );
    _;
  }

  modifier afterStartSales() {
    require(
      // solhint-disable-next-line not-rely-on-time
      (startTimestamp > 0 && block.timestamp >= startTimestamp),
      "Unavailable before sales start event"
    );
    _;
  }

       modifier beforeEndSales() {
    require(
      // solhint-disable-next-line not-rely-on-time
      block.timestamp < endTimestamp,
      "Unavailable after sales end event"
    );
    _;
  }

  modifier afterEndSales() {
    require(
      // solhint-disable-next-line not-rely-on-time
      (endTimestamp > 0 && block.timestamp >= endTimestamp),
      "Unavailable before sales end event"
    );
    _;
  }

}