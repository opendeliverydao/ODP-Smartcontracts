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
    uint256 public currentPrice;
    uint256 public currentErc20Price;
    bool public useWhitelist;
    uint256 public minTokenAmount;
    uint256 public maxTokenAmount;

    uint256 public tokenSold;


    mapping(address => bool) public isWhitelisted;


    constructor(
      address _tokenAddress,
      address _sellerAddress, 
      uint256 _currentPrice, 
      IERC20 _payment_token,
      uint256 _currentErc20Price,
      address[] memory _whitelist,
      uint256 _startTs,
      uint256 _endTs,
      bool _useWhitelist,
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
        require(_currentPrice > 0);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        minTokenAmount=_tokenAllocation[0];
        maxTokenAmount=_tokenAllocation[1];
        tokenAddress = IERC20(_tokenAddress);
        sellerAddress = _sellerAddress;
        currentPrice = _currentPrice;
        currentErc20Price = _currentErc20Price;
        startTimestamp=_startTs;
        _setIcoTimestamp(_endTs);
        emit StartSales(_startTs);
        endTimestamp=_endTs;
        paymentToken=_payment_token;
        useWhitelist=_useWhitelist;
        if (useWhitelist){
          addToWhitelist(_whitelist);
        }
        
    }


    function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
    }

    function purchaseToken(uint256 _quantity) public payable whenNotPaused afterStartSales beforeEndSales {
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
        require(msg.sender != address(0) && msg.sender != address(this));
        require(_quantity >= 1);
        require(msg.value >= currentPrice * (_quantity/1e18));
        require(currentPrice>0);

        emit Received(msg.sender, msg.value);
        tokenSold += _quantity;
        _updateUserTokenAllocation(msg.sender, _quantity);
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

        paymentToken.transferFrom(msg.sender, sellerAddress, currentErc20Price*(_quantity/1e18));
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

    function setCurrentPrice(uint256 _currentPrice) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_currentPrice > 0);
        currentPrice = _currentPrice;
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