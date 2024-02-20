// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract Scout is Ownable, ReentrancyGuard, Pausable {
  using SafeERC20 for IERC20;

  struct senderPublicKey {
    bytes32 x;
    bytes32 y;
    bytes1 sharedsecret;
    address token;
  }

  senderPublicKey[] keys;
  uint8 public constant VERSION = 1;
  address constant Stealth = address(0x0);
  address public feeReceiver;
  uint256 public feePercentage = 100; // 100 = 1% by default

  constructor() Ownable(msg.sender) {
    feeReceiver = msg.sender;
  }

  function send(bytes32 x, bytes32 y, bytes1 sharedsecret, address token) private {
    keys.push(senderPublicKey(x, y, sharedsecret, token));
  }

  function totalKeys() view external returns (uint256 count) {
    count = keys.length;
  }

  function sendAnonymously(bytes32 x, bytes32 y, bytes1 sharedsecret, address payable receiver) public payable nonReentrant whenNotPaused {
    require(msg.value > 0, "Sending amount should be more than 0");
    require(receiver != address(0x0), "Target address required");

    send(x, y, sharedsecret, Stealth);
    uint256 feeAmount = (msg.value * feePercentage) / 10000;
    payable(feeReceiver).transfer(feeAmount);
    receiver.transfer(msg.value - feeAmount);
  }

  function sendTokenAnonymously(bytes32 x, bytes32 y, bytes1 sharedsecret, address token, address receiver, uint256 amount) external nonReentrant whenNotPaused {
    require(amount > 0, "Sending amount should be greater than 0");
    require(token != address(0x0), "Token contract address cannot be Zero");
    require(receiver != address(0x0), "Receiver address cannot be Zero");

    send(x, y, sharedsecret, token);
    uint256 feeAmount = (amount * feePercentage) / 10000;
    IERC20(token).safeTransfer(feeReceiver, feeAmount);
    IERC20(token).safeTransferFrom(msg.sender, receiver, amount - feeAmount);
  }

  function getNextKeys(uint256 start) external view returns (senderPublicKey[10] memory) {
    senderPublicKey[10] memory gotKeys;

    uint256 end = start + 10;
    uint256 limit = (keys.length < end) ? keys.length : end;

    for (uint256 i=start; i < limit; i++) {
      gotKeys[i - start] = keys[i];
    }

    return gotKeys;
  }

  function setFeeReceiver(address _feeReceiver) external onlyOwner {
    require(_feeReceiver != address(0x0), "Fee receiver address cannot be zero");
    feeReceiver = _feeReceiver;
  }

  function setFeePercentage(uint256 _feePercentage) external onlyOwner {
    require(_feePercentage <= 10000, "Fee percentage exceeds 100%");
    feePercentage = _feePercentage;
  }

  function pause() external onlyOwner {
    _pause();
  }

  function unpause() external onlyOwner {
    _unpause();
  }

  function withdraw() external onlyOwner {
    require(address(this).balance > 0, "Contract balance is zero");
    payable(owner()).transfer(address(this).balance);
  }
}
