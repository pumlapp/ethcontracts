// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PumlStake is Ownable, ReentrancyGuard {

    IERC20 _puml;

    constructor() {
        _puml = IERC20(0xbc75ECc12c77506DCFd70113B15683A9a0768AB4);
    }

    using SafeMath for uint256;

    /* ========== STATE VARIABLES ========== */

    uint256 public avgBlocksPerDay = 6500;
    uint256 public blockLength = 2372500;
    uint256 public secondPerDay = 86400;

    mapping(address => uint256) public userLastUpdateTime;
    mapping(address => uint256) public userRewardStored;
    mapping(address => uint256) public userLastReward;
    mapping(address => uint256) public userLastCollect;
    mapping(address => uint256) public userRewardPaid;

    uint256 public totalSupply;
    uint256 public totalSupplyNFT;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public balancesNFT;
    mapping(uint256 => address) public stakedAssets;

    struct UserData {
        uint256 userLastUpdateTime;
        uint256 userRewardStored;
        uint256 userRewardPaid;
        uint256 userLastReward;
        uint256 userLastCollect;
        uint256 balances;
        uint256 totalBalances;
        uint256 balancesNFT;
        uint256 totalBalancesNFT;
    }

    /* ========== VIEWS ========== */

    function getStakedAssets(uint256 _tokenId) public view returns (address) {
        return stakedAssets[_tokenId];
    }

    function setStakedAssets(uint256 _tokenId, address _address) public {
        stakedAssets[_tokenId] = _address;
    }

    function setBalancesNFT(address _address, uint256 _amount, bool param) public {
        if (param) {
            balancesNFT[_address] += _amount;
            totalSupplyNFT += _amount;
        } else {
            balancesNFT[_address] -= _amount;
            totalSupplyNFT -= _amount;
        }
    }

    function setUserUpdate(address account, uint256 collectAmount) public {
        _updatePerUser(account, collectAmount);
    }

    function setUserRewardUpdate(address account, uint256 reward) public {
        _updateRewardPerUser(account, reward);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp;
    }

    function balanceOfPumlx() public view returns (uint256) {
        return _puml.balanceOf(address(this));
    }

    function _updatePerUser(address account, uint256 collectAmount) internal {
        userLastCollect[msg.sender] = collectAmount;
        userRewardStored[account] += collectAmount;
        userLastUpdateTime[account] = lastTimeRewardApplicable();
    }

    function _updateRewardPerUser(address account, uint256 reward) internal {
        userLastReward[account] = reward;
        userRewardPaid[account] += reward;
        userRewardStored[account] -= reward;
    }

    function getUserData(address account) public view returns (UserData memory) {
        UserData memory userdata = UserData({
            userLastUpdateTime: userLastUpdateTime[account],
            userRewardStored: userRewardStored[account],
            userRewardPaid: userRewardPaid[account],
            userLastReward: userLastReward[account],
            userLastCollect: userLastCollect[account],
            balances: balances[account],
            totalBalances: totalSupply,
            balancesNFT: balancesNFT[account],
            totalBalancesNFT: totalSupplyNFT
        });

        return userdata;
    }

    function setTransferPuml(address _from, address _to, uint256 _amount) public {
        require(_amount > 0, "You need to transfer at least some tokens");
        _puml.transferFrom(_from, _to, _amount);
    }

    function setDepositPuml(address _from, uint256 _amount) public {
        require(_amount > 0, "You need to deposite at least some tokens");
        _puml.transferFrom(_from, address(this), _amount);
    }


    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount, uint256 stakeamount, uint256 collectAmount) external payable nonReentrant {

        _updatePerUser(msg.sender, collectAmount);
        _stake(amount, msg.sender);
        emit Staked(msg.sender, amount);

        _puml.transferFrom(msg.sender, address(this), stakeamount);
    }

    function withdraw(uint256 amount, uint256 unstakeamount, uint256 collectAmount) public payable nonReentrant {

        _updatePerUser(msg.sender, collectAmount);
        _withdraw(amount);
        emit Withdrawn(msg.sender, amount);

        _puml.transfer(msg.sender, unstakeamount);
    }

    function claim(uint256 reward, uint256 collectAmount) public payable nonReentrant {
        if (reward > 0) {
            _updatePerUser(msg.sender, collectAmount);
            _updateRewardPerUser(msg.sender, reward);
            _puml.transfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
    }

    function claimApi(address claimer, uint256 reward, uint256 collectAmount) public payable nonReentrant {
        require( userRewardStored[claimer] > reward, "You need to transfer less than stored");
        if (reward > 0) {
            _updatePerUser(claimer, collectAmount);
            _updateRewardPerUser(claimer, reward);
            _puml.transfer(claimer, reward);

            emit RewardPaid(claimer, reward);
        }
    }

    function collect(uint256 amount) public payable nonReentrant {
        if (amount > 0) {
            userLastCollect[msg.sender] = amount;
            userRewardStored[msg.sender] += amount;
            userLastUpdateTime[msg.sender] = lastTimeRewardApplicable();

            emit Collect(msg.sender, amount);
        }
    }

    function _stake(uint256 _amount, address _staker) internal {
        totalSupply += _amount;
        balances[_staker] += _amount;
    }

    function _withdraw(uint256 _amount) internal {
        totalSupply -= _amount;
        balances[msg.sender] -= _amount;
    }

    function transferPuml(address _to, uint256 _amount) public payable nonReentrant {
        require(_amount > 0, "You need to transfer at least some tokens");
        _puml.transferFrom(msg.sender, _to, _amount);
    }

    function pickPuml(address _to, uint256 _amount) public payable nonReentrant {
        require(_amount > 0, "You need to transfer at least some tokens");
        _puml.transfer(_to, _amount);
    }

    function depositPuml(uint256 _amount) public payable nonReentrant {
        require(_amount > 0, "You need to deposite at least some tokens");
        _puml.transferFrom(msg.sender, address(this), _amount);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account, uint256 reward) {
        if (account != address(0)) {
            userLastReward[account] = reward;
            userRewardStored[account] -= reward;
        }
         _;
    }

    modifier checkAllowance(uint amount) {
        require(_puml.allowance(msg.sender, address(this)) >= amount, "Error");
        _;
    }

    /* ========== EVENTS ========== */


    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Collect(address indexed user, uint256 amount);
}
