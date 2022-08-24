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

    uint256 public rewardRate = 10;
    uint256 public lastUpdateTime;
    uint256[] public stakeData;

    mapping(address => uint256) public userLastUpdateTime;
    mapping(address => uint256) public userLastUpdateTimeFeeward;
    mapping(address => uint256) public userLastUpdateTimeStake;
    mapping(address => uint256) public userRewardStored;
    mapping(address => uint256) public userLastReward;
    mapping(address => uint256) public userRewardPaid;
    mapping(address => uint256) public userFeewardStored;
    mapping(address => uint256) public userFeeReward;

    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public balancesNFT;
    mapping(uint256 => address) public stakedAssets;

    struct StakeData {
        uint256 lastUpdateTime;
        uint256 userLastUpdateTime;
        uint256 userLastUpdateTimeStake;
        uint256 userLastUpdateTimeFeeward;
        uint256 userRewardStored;
        uint256 userFeewardStored;
        uint256 balances;
        uint256 totalBalances;
        uint256 balancesNFT;
        uint256 userRewardPaid;
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
        } else {
            balancesNFT[_address] -= _amount;
        }
    }

    function setUserRewardUpdate(address account, uint256 collect, uint256 feeward) public {
        _updatePerUser(account, collect, feeward);
        userLastUpdateTimeStake[account] = lastTimeRewardApplicable();
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp;
    }

    function _updatePerUser(address account, uint256 collect, uint256 feeward) internal {
        userRewardStored[account] += collect;
        userFeewardStored[account] += feeward;
        userLastUpdateTime[account] = lastTimeRewardApplicable();
        userLastUpdateTimeFeeward[account] = lastTimeRewardApplicable();
    }

    function _feewardPerUser(address account, uint256 feeward, uint256 collect) internal {
        userRewardStored[account] += collect;
        userFeewardStored[account] += feeward;
        userFeewardStored[account] -= collect;
        userLastUpdateTimeFeeward[account] = lastTimeRewardApplicable();
    }

    function getRewardData(address account) public view returns (StakeData memory) {
        StakeData memory stakedata = StakeData({
            lastUpdateTime: lastTimeRewardApplicable(),
            userLastUpdateTime: userLastUpdateTime[account],
            userLastUpdateTimeStake: userLastUpdateTimeStake[account],
            userLastUpdateTimeFeeward: userLastUpdateTimeFeeward[account],
            userRewardStored: userRewardStored[account],
            userFeewardStored: userFeewardStored[account],
            balances: balances[account],
            totalBalances: totalSupply,
            balancesNFT: balancesNFT[account],
            userRewardPaid: userRewardPaid[account]
        });

        return stakedata;
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

    function stake(uint256 amount, uint256 collect, uint256 feeward, uint256 stakeamount) external payable nonReentrant {

        _stake(amount, msg.sender);
        setUserRewardUpdate(msg.sender, collect, feeward);
        emit Staked(msg.sender, amount);

        _puml.transferFrom(msg.sender, address(this), stakeamount);
    }

    function withdraw(uint256 amount, uint256 collect, uint256 feeward, uint256 unstakeamount) public payable nonReentrant {

        _withdraw(amount);
        setUserRewardUpdate(msg.sender, collect, feeward);
        emit Withdrawn(msg.sender, amount);

        _puml.transfer(msg.sender, unstakeamount);
    }

    function getCollect(uint256 feeward, uint256 collect) public payable nonReentrant {

        if (collect > 0) {
            _feewardPerUser(msg.sender, feeward, collect);

            emit Collect(msg.sender, collect);
        }
    }

    function getReward(uint256 reward, uint256 collect, uint256 feeward) public payable nonReentrant {

        if (reward > 0) {
            _updatePerUser(msg.sender, collect, feeward);

            userRewardStored[msg.sender] -= reward;
            userLastReward[msg.sender] = reward;
            userRewardPaid[msg.sender] += reward;

            emit RewardPaid(msg.sender, reward);
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

    modifier updateReward(address account, uint256 feeward, uint256 collect) {
        if (account != address(0)) {
            _updatePerUser(account, feeward, collect);
            userLastUpdateTime[account] = lastTimeRewardApplicable();
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
    event Collect(address indexed user, uint256 collect);
}
