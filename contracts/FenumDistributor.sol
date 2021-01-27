// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

library MerkleProof {
  function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
    bytes32 computedHash = leaf;
    for (uint256 i = 0; i < proof.length; i++) {
      bytes32 proofElement = proof[i];
      if (computedHash <= proofElement) {
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }
    return computedHash == root;
  }
}

interface IERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IFenumDistributor {
  function token() external view returns (address);
  function merkleRoot() external view returns (bytes32);
  function isClaimed(uint256 index) external view returns (bool);
  function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external;
  event Claimed(uint256 index, address account, uint256 amount);
}


contract FenumDistributor is IFenumDistributor {
  address public immutable override token;
  bytes32 public immutable override merkleRoot;

  mapping(uint256 => uint256) private claimedBitMap;

  constructor(address token_, bytes32 merkleRoot_) public {
    token = token_;
    merkleRoot = merkleRoot_;
  }

  function isClaimed(uint256 index) public view override returns (bool) {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    uint256 claimedWord = claimedBitMap[claimedWordIndex];
    uint256 mask = (1 << claimedBitIndex);
    return claimedWord & mask == mask;
  }

  function _setClaimed(uint256 index) private {
    uint256 claimedWordIndex = index / 256;
    uint256 claimedBitIndex = index % 256;
    claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
  }

  function claim(uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) external override {
    require(!isClaimed(index), 'FenumDistributor: Drop already claimed.');
    bytes32 node = keccak256(abi.encodePacked(index, account, amount));
    require(MerkleProof.verify(merkleProof, merkleRoot, node), 'FenumDistributor: Invalid proof.');
    _setClaimed(index);
    require(IERC20(token).transfer(account, amount), 'FenumDistributor: Transfer failed.');
    emit Claimed(index, account, amount);
  }

  receive() external payable {
    revert("FenumDistributor: contract does not accept Ether.");
  }

  fallback() external {
    revert("FenumDistributor: contract action not found.");
  }
}
