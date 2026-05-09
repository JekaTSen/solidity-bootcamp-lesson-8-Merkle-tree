// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

// если на 1 день : 86400; (_periodDuration).
 
//acc1 : 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4  111   
// ["0xfe8d24c28fe9337b74618687e16ec482887ee742de119d90d94a641bb28cf423", "0x5d6ce51c8066a2fa75f7edb9db14dcc1436fe271769abf5ea19ad6c447b39205"]

//acc2 : 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2  222
//["0x459757c5316d8547234e86f0aea0d1adf624eda9061253d253f59ef4a834424b", "0xe9e689f494b358f04aa46b95ea335e9c0b22bec228830e322a2d9237fe074022"]

//acc3 : 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db  333
//acc4 : 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB  444

//owner acc15: 0xdD870fA1b7C4700F2BD7f44238821C26f7392148

//treasury acc10: 0x0A098Eda01Ce92ff4A4CCb7A4fFFb5A43EBC70DC

//merkleroot : 0xcdbed6ab3b45edbd48c14f32f2c04d4deb362aa223dcb2a2efe501ecd6c8d09f



import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Claimer is Ownable {
    IERC20 public token;
    bytes32 public merkleRoot;
    address public treasury;
    uint256 public totalClaimed;
    uint256 public endTimeClaimPeriod;

    mapping(address => bool) public hasClaimed;

    event TokenClaimed(address claimer, uint256 amount, uint256 timestamp);
    event TimeHasBeenExtended(uint256 newEndTime);

    error AlreadyClaimed();
    error InvalidProof();
    error TransferFailed();
    error ClaimPeriodEnded();
    error ClaimPeriodIsNotEnded();
    error InsufficientAllowance();

    constructor(address _tokenAddress, bytes32 _merkleRoot, address _treasury, uint256 _periodDuration) Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
        merkleRoot = _merkleRoot;
        treasury = _treasury;
        endTimeClaimPeriod = block.timestamp + _periodDuration;
    }

    function claim(uint256 _amount, bytes32[] calldata _proof) external {
        require(block.timestamp <= endTimeClaimPeriod, ClaimPeriodEnded());
        require(!hasClaimed[msg.sender], AlreadyClaimed());
        require(token.allowance(treasury, address(this)) >= _amount, InsufficientAllowance());
        require(canClaim(msg.sender, _amount, _proof), InvalidProof());
    
        hasClaimed[msg.sender] = true;
        totalClaimed += _amount;

        require(token.transferFrom(treasury, msg.sender, _amount), TransferFailed());
        emit TokenClaimed(msg.sender, _amount, block.timestamp);
    }


    function canClaim(address _addressToCheck, uint256 _amount, bytes32[] calldata _proof) public view returns (bool) {
        return _verifyMerkleTree(_addressToCheck, _amount, _proof) && !hasClaimed[_addressToCheck];
    }



    function _verifyMerkleTree (address _address, uint256 _amount, bytes32[] calldata _proof) internal view returns (bool) {
        bytes32 leaf = keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(_address, _amount)
                )
            )
        );
        bool valid = MerkleProof.verify(_proof, merkleRoot, leaf); 
        return valid;  
    } 



    function extendPeriodToClaim(uint256 _timeToAdd) external onlyOwner {
        endTimeClaimPeriod += _timeToAdd;
        emit TimeHasBeenExtended(endTimeClaimPeriod);
    }


    function recoverUnclaimed () external onlyOwner {
        require(block.timestamp > endTimeClaimPeriod, ClaimPeriodIsNotEnded());
        require(token.transferFrom(treasury, msg.sender, token.balanceOf(treasury)), TransferFailed());
    }


    //Внедрить totalClaimed √
    //Верификация без клейма canClaim() view √
    //Добавить возможность установить временные рамки клейма √
    //Добавить функцию recoverUnclaimed, чтобы склеймить все оставшиеся средства на аккаунт овнера √
}
