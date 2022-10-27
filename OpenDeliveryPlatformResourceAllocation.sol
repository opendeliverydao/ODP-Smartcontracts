// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";

interface IWETH is IERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function withdraw(uint256 wad, address user) external;
}

contract ODPResourceAllocation is Ownable {

    event Deposit(address indexed src, uint256 value);
    event Withdrawal(address indexed dst, uint256 value);
    event WithdrawalToken(address indexed dst, uint256 value,address tokenAddress);
    event AddOrUpdateReceiver(address indexed dst, uint256 ratio, address destinationToken);
    event FallbackAmount(uint256 value);

    using Counters for Counters.Counter;
    Counters.Counter private destinations;
    
    mapping(uint256 => address) public destinationAddress;
    mapping(uint256 => address) public destinationTokenAddress;
    mapping(uint256 => uint256) public destinationRatio;
    uint256 destinationRatioSum=0;

    address private uniswapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address private wrappedNativeTokenAddress= 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address private fallBackAddress;
    uint24 private uniswapFeeParam=3000;

    ISwapRouter public uniswapRouter;

    constructor(address _fallBackAddress) {
        uniswapRouter=ISwapRouter(uniswapRouterAddress);
        fallBackAddress=_fallBackAddress;
    }

    function deposit() public payable{
        uint256 contractTotalAmount=(msg.value/100)*destinationRatioSum;
        uint256 totalAmount=0;
        
        IWETH wrappedNativeToken=IWETH(wrappedNativeTokenAddress);
        if (contractTotalAmount>0){
            wrappedNativeToken.deposit{value:contractTotalAmount}();
            wrappedNativeToken.approve(uniswapRouterAddress, contractTotalAmount);    
            for (uint256 i = 1; i <= destinations.current(); i++) {
                if (destinationRatio[i]>0){
                    uint256 destinationAmount=(msg.value/100)*(destinationRatio[i]);
                    if (destinationTokenAddress[i]!=wrappedNativeTokenAddress){
                        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                            .ExactInputSingleParams({
                                tokenIn: wrappedNativeTokenAddress,
                                tokenOut: destinationTokenAddress[i],
                                fee: uniswapFeeParam,
                                recipient: destinationAddress[i],
                                deadline: block.timestamp,
                                amountIn: destinationAmount,
                                amountOutMinimum: 0,
                                sqrtPriceLimitX96: 0
                            });
                        uniswapRouter.exactInputSingle(params);
                    } else {
                        SafeERC20.safeTransfer(IERC20(wrappedNativeToken), destinationAddress[i], destinationAmount);
                    }
                    totalAmount+=destinationAmount;
                }
            }
        }
        
        require(totalAmount==contractTotalAmount,"totalAmount!=contractTotalAmount");
        
        uint256 remainingAmount=msg.value-totalAmount;
        if (remainingAmount>0){
            //SafeERC20.safeTransfer(IERC20(wrappedNativeToken), fallBackAddress , fallBackAddress);
            Address.sendValue(payable(fallBackAddress), remainingAmount);
            emit FallbackAmount(remainingAmount);
        }
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 _amount) public onlyOwner{
        require(address(this).balance>=_amount,"insuficient balance");
        if (_amount==0){
            _amount=address(this).balance;
        }
        Address.sendValue(payable(msg.sender), _amount);
        emit Withdrawal(msg.sender, _amount);
    }

    function withdraw(address _tokenAddress,uint256 _amount) public onlyOwner{
        require(IERC20(_tokenAddress).balanceOf(address(this))>=_amount,"insuficient balance");
        if (_amount==0){
            _amount=IERC20(_tokenAddress).balanceOf(address(this));
        }
        SafeERC20.safeTransfer(IERC20(_tokenAddress), address(msg.sender), _amount);
        emit WithdrawalToken(msg.sender, _amount, _tokenAddress);
    }

    function addDestination(address _destinationAddress,uint256 _ratio,address _destinationToken) public onlyOwner{
        require(destinationRatioSum + _ratio <= 100,"Sum of proportions must be less than or equal to 100");
        uint256 destinationId = destinations.current()+1;
        destinationTokenAddress[destinationId]=_destinationToken;
        destinationAddress[destinationId]=_destinationAddress;
        destinationRatio[destinationId]=_ratio;
        destinations.increment();
        destinationRatioSum+=_ratio;
        emit AddOrUpdateReceiver(_destinationAddress, _ratio, _destinationToken);
    }

    function updateDestination(uint256 _destinationId,address _destinationAddress,uint256 _ratio,address _destinationToken) public onlyOwner{
        require(destinationRatioSum- destinationRatio[_destinationId] + _ratio <= 100,"Sum of proportions must be less than or equal to 100");
        destinationTokenAddress[_destinationId]=_destinationToken;
        destinationAddress[_destinationId]=_destinationAddress;
        destinationRatioSum-=destinationRatio[_destinationId];
        destinationRatio[_destinationId]=_ratio;
        destinationRatioSum+=_ratio;
        emit AddOrUpdateReceiver(_destinationAddress, _ratio, _destinationToken);
    }

    function removeDestination(uint256 destinationId) public onlyOwner{
        require(destinationRatioSum > 0,"No destinations");
        destinationRatioSum-=destinationRatio[destinationId];
        destinationRatio[destinationId]=0;
        emit AddOrUpdateReceiver(destinationTokenAddress[destinationId], 0, destinationTokenAddress[destinationId]);
    }

    function updateUniswapFeeParam(uint24 _uniswapFeeParam) public onlyOwner{
        uniswapFeeParam=_uniswapFeeParam;
    }

    function updateUniswapRouterAddressParam(address _uniswapRouterAddress) public onlyOwner{
        uniswapRouterAddress=_uniswapRouterAddress;
    }

    function updateWrappedNativeTokenAddressParam(address _wrappedNativeTokenAddress) public onlyOwner{
        wrappedNativeTokenAddress=_wrappedNativeTokenAddress;
    }

    function updateFallbackAddress(address _fallBackAddress) public onlyOwner{
        fallBackAddress=_fallBackAddress;
    }

    function getFallbackAddress() public view returns (address){
        return fallBackAddress;
    }

    function getWrappedNativeTokenAdderss() public view returns (address){
        return wrappedNativeTokenAddress;
    }

    function getUniswapRouterAddress() public view returns (address){
        return uniswapRouterAddress;
    }
    function getUniswapUniswapFeeParam() public view returns (uint24){
        return uniswapFeeParam;
    }
    function getDestinationCount() public view returns (uint256){
        return destinations.current();
    }

    function getDestinationRatioSum() public view returns (uint256){
        return destinationRatioSum;
    }

}
