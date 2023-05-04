/**                                
                              :^~!77!^:                           
                           ^?J?!~^^^^!7??^                        
                         .JJ^      .~!!~~?Y^.~???.                
                        .P!       75~^~7J7:5G!: YY.:^.            
                       .5J       .B^:G#Y:YJ ?Y:~5P?7!P!           
                      .G@^ .!?7:  57.B@@Y.B~.GY!:    G7           
                      ^#B^ :BBGG. .57:YP!.G~.:     .57            
                      .BB7  7PY!   .?Y7~!Y?       ^P!:!.          
                       J#G   ..      .^~^.       ~B5JJB! ^75^     
                        !B7                   .:^Y#?!~PPYYJ#:     
                         :B:                  .!!!?7!!!7!!G!      
                          75             ^~~~~~!!!!!!!!~7G!       
                           JJ       ... ^!!!!!!!!!!!!!!YP^        
                            Y?     ~!!!~!!!!!!!!!!!!!JP?.         
                             JJ:::^!!!!!!!!!!!!!!!7J5?:           
                              !5J!!!!!!!!!!!!!7?YY?~.             
                               .JYJ??77777??YYY#J                 
                                 .^~7????JGY::?PP                 
                                        .7PY   !:                 
                                          :.       
                    website: https://www.memebook.xyz/home
                    twitter: https://twitter.com/memebook_xyz
                    whitepapper_en: https://whitepaper.memebook.xyz/en/
                    whitepapper_zh: https://whitepaper.memebook.xyz/zh/
 */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

contract MemeReward is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    struct User {
        uint256 claimed;
        uint64 latestTimestamp;
    }
    bool inClaim;
    bytes32 public claimRoot; // upload by server node

    mapping(address => bool) public operators;
    mapping(address => User) public userClaim;

    event Received(address Sender, uint256 Value);
    event SetOperator(address Operator, bool Flag);
    event ClaimedSuccess(address Receiver, uint256 Amount);
    event UpdateClaimRoot(address Sender, uint256 Timestamp);

    modifier onlyOperator() {
        require(operators[msg.sender], "onlyOperatorCall");
        _;
    }

    modifier claiming() {
        require(!inClaim, "inClaiming");
        inClaim = true;
        _;
        inClaim = false;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        inClaim = false;
        operators[_msgSender()] = true;
        emit SetOperator(_msgSender(), true);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function claim(
        uint256 _amount,
        bytes32[] memory _proof
    ) external claiming whenNotPaused {
        require(tx.origin == _msgSender(), "OnlyOrigin");
        require(
            checkoutEligibility(_msgSender(), _amount, _proof),
            "VerifyFailed!"
        );
        User memory user = userClaim[_msgSender()];
        require(_amount >= user.claimed, "NoReward");
        uint256 pendingClaim = _amount - user.claimed;
        user.claimed = _amount;
        user.latestTimestamp = uint64(block.timestamp);
        userClaim[_msgSender()] = user;

        payable(_msgSender()).transfer(pendingClaim);
        emit ClaimedSuccess(_msgSender(), pendingClaim);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setOperator(address operator, bool flag) public onlyOwner {
        operators[operator] = flag;
        emit SetOperator(operator, flag);
    }

    function setClaimRoot(bytes32 root_hash) public onlyOperator {
        claimRoot = root_hash;
        emit UpdateClaimRoot(_msgSender(), block.timestamp);
    }

    function withdrawPayments(address token_) external onlyOwner {
        if (token_ == address(0x0)) {
            (bool sent, ) = msg.sender.call{value: address(this).balance}(
                new bytes(0)
            );
            require(sent, "WithdrawFail");
            return;
        }
        IERC20Upgradeable token = IERC20Upgradeable(token_);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
    }

    function checkoutEligibility(
        address account,
        uint256 amount,
        bytes32[] memory proof
    ) internal view returns (bool) {
        return
            MerkleProofUpgradeable.verify(
                proof,
                claimRoot,
                _getKey(account, amount)
            );
    }

    function _getKey(
        address owner_,
        uint256 amount
    ) internal pure returns (bytes32) {
        bytes memory n = abi.encodePacked(_trs(owner_), "-", _uint2str(amount));
        bytes32 q = keccak256(n);
        return q;
    }

    function _uint2str(
        uint256 _i
    ) internal pure returns (bytes memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return bstr;
    }

    function _trs(address a) internal pure returns (string memory) {
        return _toString(abi.encodePacked(a));
    }

    function _toString(
        bytes memory data
    ) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < data.length; i++) {
            str[2 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
