// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PumlStake is Ownable, ReentrancyGuard {

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


    /* ========== MUTATIVE FUNCTIONS ========== */

    function stake(uint256 amount, uint256 collect, uint256 feeward, address staker) external payable nonReentrant {

        _stake(amount, staker);
        setUserRewardUpdate(staker, collect, feeward);
        emit Staked(staker, amount);
    }

    function withdraw(uint256 amount, uint256 collect, uint256 feeward) public payable nonReentrant {

        _withdraw(amount);
        setUserRewardUpdate(msg.sender, collect, feeward);
        emit Withdrawn(msg.sender, amount);
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

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account, uint256 feeward, uint256 collect) {
        if (account != address(0)) {
            _updatePerUser(account, feeward, collect);
            userLastUpdateTime[account] = lastTimeRewardApplicable();
        }
         _;
    }

    /* ========== EVENTS ========== */


    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Collect(address indexed user, uint256 collect);
}
