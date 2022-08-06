// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


interface IERC20 {
  function totalSupply() external view returns (uint256);
 
  function balanceOf(address who) external view returns (uint256);
 
  function allowance(address owner, address spender)
    external view returns (uint256);
 
  function transfer(address to, uint256 value) external returns (bool);
 
  function approve(address spender, uint256 value)
    external returns (bool);
 
  function transferFrom(address from, address to, uint256 value)
    external returns (bool);
}

contract MemeBookPosts {
    enum PTypeEnum{PUREPOST , POSTWITHAIRDROP  } 
    struct AirDropInfo {
        uint256 share;
        uint256 amountPerShare;
        address erc20Addr;
        string passwordSha3 ;
    }
    struct PostContent {
        string text;
        string[] urlPics ;
        bytes32[] ipfsPics ;
        AirDropInfo airDropInfo ;
    } 

    event PostEvent(
        PTypeEnum pTypeEnum ,
        address indexed _from ,
        PostContent postContent 
    ) ;

    function po(PostContent memory p)  external returns(bool) {
        emit PostEvent(PTypeEnum.PUREPOST ,msg.sender ,p) ;
        poIndex += 1 ;
        return true ;
    }

    uint256 poIndex = 0 ;
    mapping (uint256 => AirDropInfo) poAirDropMap ;
    mapping (uint256 => mapping(address => bool)) poAirDropClaimAddrMap ;
    mapping (uint256 => uint256) poAirDropClaimCount ;

    function poWithAirDrop(PostContent memory p) external returns(bool) {
        IERC20(p.airDropInfo.erc20Addr).transferFrom(msg.sender, address(this), p.airDropInfo.amountPerShare * p.airDropInfo.share);
        emit PostEvent(PTypeEnum.POSTWITHAIRDROP ,msg.sender ,p) ;
        poIndex += 1 ;
        poAirDropMap[poIndex] = p.airDropInfo ;
        return true ;
    }

    function claimAirDrop(uint256 poIndex,string memory originPassword) external returns(bool) {
        AirDropInfo poAirDrop = poAirDropMap[poIndex] ; 
        required(poAirDropClaimCount[poIndex] < poAirDrop.share,"claim is over" ) ;
        required(sha3(originPassword)!=poAirDrop.passwordSha3,"password verify fail") ;
        required(poAirDropClaimAddrMap[poIndex][msg.sender] == 0,"u already claim") ;
        IERC20(poAirDrop.erc20Addr).transferFrom(address(this),msg.sender ,poAirDrop.amountPerShare);
        poAirDropClaimCount[poIndex] += 1 ;
        poAirDropClaimAddrMap[poIndex][msg.sender] = true ;
        return true ;
    }

}