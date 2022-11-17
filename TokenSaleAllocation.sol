// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenAllocation {
  using SafeERC20 for IERC20;

  uint256 public constant THIRTY_DAYS_IN_SECONDS = 2592000;

  address public immutable tokenOwner;
  IERC20 public immutable myToken;
  uint256 public immutable unlockAtICOPercent;
  uint256 public immutable cliffMonths;
  uint256 public immutable vestingPeriodMonths;

  uint256 public icoTimestamp;

  event Claimed(
    address indexed wallet,
    uint256 indexed monthIndex,
    uint256 indexed value
  );

  struct UserInfo {
    uint256 totalTokens;
    uint256 remainingTokens;
    int256 lastClaimMonthIndex;
  }

  mapping(address => UserInfo) public addressToUserInfo;

  constructor(
    address _tokenOwner,
    IERC20 _myToken,
    uint256 _unlockAtICOPercent,
    uint256 _cliffMonths,
    uint256 _vestingPeriodMonths
  ) {
    require(_tokenOwner != address(0), "zero tokenOwner");
    require(_myToken != IERC20(address(0)), "zero myToken");
    require(_unlockAtICOPercent <= 100, "unlockAtICOPercent must lte 100");

    tokenOwner = _tokenOwner;
    myToken = _myToken;
    unlockAtICOPercent = _unlockAtICOPercent;
    cliffMonths = _cliffMonths;
    vestingPeriodMonths = _vestingPeriodMonths;
  }

  function _setIcoTimestamp(uint256 _icoTimestamp) internal {
    icoTimestamp = _icoTimestamp;
  }

  function _getUserTotalTokens(address wallet) internal view returns (uint256) {
    return addressToUserInfo[wallet].totalTokens;
  }

  function _updateUserTokenAllocation(address wallet, uint256 totalTokens)
    internal
    beforeICO
  {
    UserInfo storage userInfo = addressToUserInfo[wallet];
    userInfo.totalTokens += totalTokens;
    userInfo.remainingTokens += totalTokens;
    userInfo.lastClaimMonthIndex = -1;
  }

  modifier beforeICO() {
    require(
      // solhint-disable-next-line not-rely-on-time
      icoTimestamp == 0 || block.timestamp < icoTimestamp,
      "Unavailable after ICO"
    );
    _;
  }

  modifier afterICO() {
    require(
      // solhint-disable-next-line not-rely-on-time
      icoTimestamp > 0 && block.timestamp >= icoTimestamp,
      "Unavailable before ICO"
    );
    _;
  }

  function _unlockedAtIcoAmount(UserInfo memory userInfo)
    private
    view
    returns (uint256)
  {
    return (userInfo.totalTokens * unlockAtICOPercent) / 100;
  }

  function _releaseAmount(UserInfo memory userInfo, uint256 monthIndex)
    private
    view
    returns (uint256)
  {
    if (cliffMonths > 0 && monthIndex <= cliffMonths) {
      return 0;
    } else if (monthIndex > (cliffMonths + vestingPeriodMonths)) {
      return 0;
    } else if (monthIndex == 0) {
      return _unlockedAtIcoAmount(userInfo);
    } else {
      // e.g. 100 distributed in 1+3 months with 20 at IDO should be 20, 26, 26, 28

      // starts at 1
      uint256 _vestingIndex = monthIndex - cliffMonths;

      // e.g. 20
      uint256 _unlockedAtIco = _unlockedAtIcoAmount(userInfo);

      // e.g. 26
      uint256 _amount = (userInfo.totalTokens - _unlockedAtIco) /
        vestingPeriodMonths;

      // e.g. 20, 46, 72
      uint256 _distributedTokens = _unlockedAtIco +
        _amount *
        (_vestingIndex - 1);

      // e.g. 80, 54, 28
      uint256 _remainingTokens = userInfo.totalTokens - _distributedTokens;

      // e.g. false, false, true
      if (_remainingTokens < 2 * _amount) {
        _amount = _remainingTokens;
      }

      // e.g. 26, 26, 28
      return _amount;
    }
  }

  /**
   * @dev Since this function has the afterICO modifier, timestamp >= icoTimestamp.
   *      Because of that, the while loop ALWAYS enters, so the uint256
   *      cast does not underflow and the return value is at least 0
   */
  function _getMonthIndexFromTimestamp(uint256 timestamp)
    private
    view
    afterICO
    returns (uint256)
  {
    int256 index = -1;

    uint256 t = icoTimestamp;
    while (t <= timestamp) {
      index++;
      t += THIRTY_DAYS_IN_SECONDS;
    }

    return uint256(index);
  }

  function claim() public afterICO {
    UserInfo storage userInfo = addressToUserInfo[msg.sender];
    require(userInfo.remainingTokens > 0, "Not enough tokens");

    // solhint-disable-next-line not-rely-on-time
    uint256 nowTimestamp = block.timestamp;

    uint256 startMonthIndex = uint256(userInfo.lastClaimMonthIndex + 1);
    uint256 endMonthIndex = _getMonthIndexFromTimestamp(nowTimestamp);

    for (uint256 i = startMonthIndex; i <= endMonthIndex; i++) {
      uint256 amount = _releaseAmount(userInfo, i);
      if (amount > 0 && userInfo.remainingTokens > 0) {
        userInfo.remainingTokens -= amount;
        userInfo.lastClaimMonthIndex = int256(i);
        myToken.safeTransferFrom(tokenOwner, msg.sender, amount);
        emit Claimed(msg.sender, i, amount);
      }
    }
  }
}
