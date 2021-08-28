// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./lib.sol";

interface LockToken{
    struct LockRecord {
        address user;
        uint256 tokenAmount;
        uint256 lockTokenAmount;
        uint256 lockBlockNumber;
        uint256 unlockBlockNumber;
        bool unlocked;
    }
    function  totalLockTokenAmount()external view returns(uint256 _totalLockTokenAmount);
    function getUserAllStakedToken(address _user) external view returns (uint256 _tokenAmount, uint256 _lockTokenAmount);
    function getLockRecord(uint256 _id) view external returns (address _user, uint256 _tokenAmount, 
        uint256 _lockTokenAmount, uint256 _lockBlockNumber, uint256 _unlockBlockNumber, bool _unlocked);
    function lock(address _forUser, uint256 _amount, uint256 _lockTokenBlockNumber) external returns (uint256 _id) ;
    function unlock(address _forUser,uint256 _lockRecordId) external;
    function stake(address _forUser, uint256 _tokenAmount) external;
    function unstake(address _forUser, uint256 _tokenAmount) external;
}


contract StakingPool is Ownable, CheckContract, BaseMath {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    uint8 public constant ZERO = 0;
    IERC20 public token;
    IERC20 public lockToken;
    LockToken public lockContract;
    uint256 public startBlock;
    uint256 public minimumLockAmount;
    
    // the total rewards of tokens
    mapping(IERC20 => uint) tokensRewards; 
    mapping(IERC20 => bool) tokens;
    
    // all the tokens being reward
    IERC20[] public rewardTokens;
    mapping(address => mapping (uint => bool)) userLockId;
    mapping(address => mapping(IERC20 => uint)) userTokenSnapshots;

    // --- Events ---
    event LockTokenSet(IERC20 _lockToken);
    event TokenSet(IERC20 _token);
    event LockContractSet(LockToken _lockToken);
    event StakeChanged(address indexed _staker, uint _newStake);
    event Harvest(address indexed _staker, IERC20 _tokenAddress, uint _tokenGain);
    event RewardUpdated(IERC20 _rewardtokenAddress, uint _F_Token);
    event totalLockTokenUpdated(uint _totalLockToken);
    event StakerSnapshotsUpdated(address _staker, IERC20 _token, uint _reward);
    event EmergencyStop(address indexed _user, address _to);
    event EmergencyUnstake(address indexed _user, uint256 indexed _amount);
    event EmergencyUnlock(address indexed _user, uint256 indexed _lockId);
        
    bool stopped;
    modifier notStopped virtual {
            require(!stopped,"StakingPool : this pool is stopped!"); 
        _;
    }
    
    mapping(address => bool) public admins;
    modifier onlyAdmin virtual {
        require( admins[msg.sender] || msg.sender == owner()); 
        _;
    }
    modifier started virtual {
        require(startBlock <= block.number,"StakingPool: Pool not start!");
        _;
    }
    
    constructor(){
        startBlock = block.number;
    }
    
    function setAddresses
    (
        IERC20 _token,
        LockToken _lockContract,
        IERC20 _lockToken
    ) 
        external 
        onlyOwner 
         
    {
        checkContract(address(_token));
        checkContract(address(_lockContract));
        checkContract(address(_lockToken));
        token = _token;
        lockContract = _lockContract;
        lockToken = _lockToken;
        emit LockTokenSet(_lockToken);
        emit TokenSet(_token);
        emit LockContractSet(_lockContract);
    }
    
    function setAdmin(address _account, bool _isAdmin) external onlyOwner {
        admins[_account] = _isAdmin;
    }
    
    function setMinimumLockQuantity(uint256 _minimumLockAmount) public onlyOwner {
        minimumLockAmount = _minimumLockAmount;
    }

    function lock(address _forUser, uint256 _amount, uint256 _lockTokenBlockNumber) external started notStopped {
        _requireNonZeroAmount(_amount);
        require(_forUser != address(0), 'StakingPool : _forUser can not be Zero');
        require(_amount >= minimumLockAmount, 'StakingPool : token amount must be greater than minimumLockAmount');
        harvestAll(_forUser);
        token.safeTransferFrom(msg.sender, address(this), _amount);
        token.safeApprove(address(lockContract), _amount);
        lockContract.lock(_forUser, _amount, _lockTokenBlockNumber);
    }

    // If requested amount > stake, send their entire stake.
    function unlock(address _forUser, uint256 _lockRecordId) external  {
        harvestAll(_forUser);
        emergencyUnlock(_forUser, _lockRecordId);
    }
    
    function emergencyUnlock(address _forUser, uint256 _lockRecordId) public{
        require(_forUser != address(0), 'StakingPool : _forUser can not be Zero');
        (, uint256 _userLockTokenAmount) = lockContract.getUserAllStakedToken(_forUser);
        _requireUserHasStake(_userLockTokenAmount);
        (,,uint _lockTokenAmount,,,) = lockContract.getLockRecord(_lockRecordId);
        lockToken.safeTransferFrom(msg.sender, address(this), _lockTokenAmount);
        
        lockToken.safeApprove(address(lockContract), _lockTokenAmount);
        lockContract.unlock(_forUser,_lockRecordId);
        emit EmergencyUnlock(_forUser, _lockRecordId);
    }
    
    function stake(address _forUser, uint256 _tokenAmount) public started notStopped {
        require(_forUser != address(0), 'StakingPool : _forUser can not be Zero');
        _requireNonZeroAmount(_tokenAmount);
        require(_tokenAmount >= minimumLockAmount, 'StakingPool :  token amount must be greater than minimumLockAmount');
        harvestAll(_forUser);
        require(token.transferFrom(msg.sender, address(this), _tokenAmount), "not support!");
        token.safeApprove(address(lockContract), _tokenAmount);
        lockContract.stake(_forUser, _tokenAmount);
    }
    
    function unstake(address _forUser, uint256 _tokenAmount) public  {
        harvestAll(_forUser);
        emergencyUnstake(_forUser, _tokenAmount);
    }
    
    function emergencyUnstake(address _forUser, uint256 _tokenAmount)public {
        require(_forUser != address(0), 'StakingPool: _forUser can not be Zero');
        require(msg.sender != address(0), 'StakingPool: _forUser can not be Zero');
        require(_tokenAmount >= 0, 'StakingPool: token amount must be greater than Zero');
        lockToken.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        lockToken.safeApprove(address(lockContract), _tokenAmount);
        lockContract.unstake(_forUser, _tokenAmount);
        emit EmergencyUnstake(_forUser, _tokenAmount);
    }
    
    function harvest(address _forUser, IERC20 _rewardToken) public {
        require(_forUser != address(0), 'StakingPool: _forUser can not be Zero');
        require(address(_rewardToken) != address(0), 'StakingPool: _rewardToken can not be Zero');
        require(tokens[_rewardToken], "StakingPool: not support!");
        (, uint256 _lockTokenAmount) = lockContract.getUserAllStakedToken(msg.sender);
        _requireUserHasStake(_lockTokenAmount);
        uint reward = _pendingReward(_rewardToken, msg.sender);
        _rewardToken.safeTransfer(msg.sender, reward);
        emit Harvest(msg.sender, _rewardToken, reward);
        _updateUserSnapshot(msg.sender, _rewardToken);
    }
    
    function harvestAll(address _forUser) public {
        require(_forUser != address(0), 'StakingPool: _forUser can not be Zero');
        for (uint i = 0; i < rewardTokens.length; i++){
            harvest(_forUser, rewardTokens[i]);
        }
    }

    function increaseTokenReward(IERC20 _token, uint _reward) external notStopped started onlyOwner{
        // _requireCallerIsBorrowerOperations();
        uint tokenRewardPerLockTokenStaked;
        require(!tokens[_token], "StakingPool : _token not supported!");
        if (lockContract.totalLockTokenAmount() > 0) {
            tokenRewardPerLockTokenStaked = _reward.mul(DECIMAL_PRECISION).div(lockContract.totalLockTokenAmount());
        }
        tokensRewards[_token] = tokensRewards[_token].add(tokenRewardPerLockTokenStaked);
        emit RewardUpdated(_token, tokensRewards[_token]);
    }

    // --- Pending reward functions ---
    function pendingReward(IERC20 _token ,address _user) external view  returns (uint) {
        return _pendingReward(_token, _user);
    }

    function _pendingReward( IERC20 _token, address _user) internal view returns (uint) {
        uint tokenSnapshot = userTokenSnapshots[_user][_token];
        (, uint256 _lockTokenAmount) = lockContract.getUserAllStakedToken(msg.sender);
         _requireUserHasStake(_lockTokenAmount);
        return _lockTokenAmount.mul(tokensRewards[_token].sub(tokenSnapshot)).div(DECIMAL_PRECISION);
    }

    function _updateUserSnapshot(address _user, IERC20 _rewardToken)internal{
         if (address(_rewardToken) != address(0)){
            userTokenSnapshots[_user][_rewardToken] = tokensRewards[_rewardToken];
            emit StakerSnapshotsUpdated(_user, _rewardToken, tokensRewards[_rewardToken]);
        }
    }

    // --- Account auth functions ---
    function _addRewardToken(IERC20 _newToken)external onlyOwner {
        require(!tokens[_newToken],"StakingPool : Token is existing!");
        require(address(_newToken) != address(0), "StakingPool : Account cannot be zero address");
        rewardTokens.push(_newToken);
        tokens[_newToken] = true;
    }
    
    function _delRewardToken(IERC20 _delToken)external onlyOwner {
        require(address(_delToken) != address(0), "StakingPool : Account cannot be zero address");
        tokens[_delToken] = false;
        for (uint256 i = 1; i < rewardTokens.length; i++){
            if (rewardTokens[i] == _delToken){
                for ( uint256 j = i; j < rewardTokens.length - 1; j++) {
                    rewardTokens[j] = rewardTokens[j + 1];
                }
                rewardTokens.length - 1;
                break;
            }
        }
    }
    
    function emergencyStop(address  _to) external onlyOwner {
        if (_to == address(0)) {
            _to = msg.sender;
        }
         for (uint i = 0; i < rewardTokens.length; i++){
            if (address(rewardTokens[i]) != address(0)){
                uint addrBalance = rewardTokens[i].balanceOf(address(this));
                if (addrBalance > ZERO) {
                   rewardTokens[i].safeTransfer(_to, addrBalance);
                }  
            }
        }
        stopped = true;
        emit EmergencyStop(msg.sender, _to);
    }
    
    function restart() external onlyOwner{
        stopped = true;
    }
    
    function _requireUserHasStake(uint _currentStake) internal pure {  
        require(_currentStake > 0, 'StakingPool : User must have a non-zero stake');  
    }

    function _requireNonZeroAmount(uint _amount) internal pure {
        require(_amount > 0, 'StakingPool : Amount must be non-zero');
    }

}
