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
    mapping(address => uint) public stakes;
    uint public totalLockTokenAmount;
    
    IERC20 public token;
    IERC20 public lockToken;
    LockToken public lockContract;
    
    uint256 public minimumLockAmount;
    
    // the total rewards of tokens
    mapping(IERC20 => uint) tokensRewards; 
    mapping(IERC20 => bool) tokens;
    
    // all the tokens being reward
    IERC20[] public rewardTokens;
    
    mapping(address => mapping (uint => bool)) userLockId;
    mapping(address => mapping(IERC20 => uint)) userTokenSnapshots;
    
    // mapping(address => IERC20) Tokens;
    // ILQTYToken public lqtyToken;
    // ILUSDToken public lusdToken;
    
    mapping(IERC20 => uint) internal Gains;
    // address public troveManagerAddress;
    // address public borrowerOperationsAddress;
    // address public activePoolAddress;

    // --- Events ---
    event LockTokenSet(IERC20 _lockToken);
    event TokenSet(IERC20 _token);
    event LockContractSet(LockToken _lockToken);
    // event TroveManagerAddressSet(address _troveManager);
    // event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    // event ActivePoolAddressSet(address _activePoolAddress);

    event StakeChanged(address indexed _staker, uint _newStake);
    event StakingGainsWithdrawn(address indexed _staker, IERC20 _tokenAddress, uint _tokenGain);
    // event F_ETHUpdated(uint _F_ETH);
    event RewardUpdated(IERC20 _rewardtokenAddress, uint _F_Token);
    event totalLockTokenUpdated(uint _totalLockToken);
    // event EtherSent(address _account, uint _amount);
    event StakerSnapshotsUpdated(address _staker, IERC20 _token, uint _reward);
    event EmergencyStop(address indexed _user, address _to);
		
    event EmergencyUnlock(address indexed _user, uint256 indexed _lockId);
		
		bool stopped;
    modifier notStopped virtual {
            require(!stopped,"this pool is stopped!"); 
        _;
    }
    
    mapping(address => bool) public admins;
    modifier onlyAdmin virtual {
            require( admins[msg.sender] || msg.sender == owner()); 
        _;
    }
    
    function setAddresses
    (
        IERC20 _token,
        LockToken _lockContract,
        IERC20 _lockToken
        
        // address _troveManagerAddress, 
        // address _borrowerOperationsAddress,
        // address _activePoolAddress
    ) 
        external 
        onlyOwner 
         
    {
        checkContract(address(_token));
        checkContract(address(_lockContract));
        checkContract(address(_lockToken));
       
        // checkContract(_troveManagerAddress);
        // checkContract(_borrowerOperationsAddress);
        // checkContract(_activePoolAddress);

        token = _token;
        lockContract = _lockContract;
        lockToken = _lockToken;
     
        // troveManagerAddress = _troveManagerAddress;
        // borrowerOperationsAddress = _borrowerOperationsAddress;
        // activePoolAddress = _activePoolAddress;

        emit LockTokenSet(_lockToken);
        emit TokenSet(_token);
        emit LockContractSet(_lockContract);
       
        // emit TroveManagerAddressSet(_troveManagerAddress);
        // emit BorrowerOperationsAddressSet(_borrowerOperationsAddress);
        // emit ActivePoolAddressSet(_activePoolAddress);

    }
    
    function setAdmin(address _account, bool _isAdmin) external onlyOwner {
        admins[_account] = _isAdmin;
    }
    
    function setMinimumLockQuantity(uint256 _minimumLockAmount) public onlyAdmin {
        minimumLockAmount = _minimumLockAmount;
    }
    
    // If caller has a pre-existing stake, send any accumulated ETH and LUSD gains to them. 
    function lock(address _forUser, uint256 _amount, uint256 _lockTokenBlockNumber) external notStopped {
        _requireNonZeroAmount(_amount);
        require(_forUser != address(0), 'LockToken: _forUser can not be Zero');
        require(_amount >= minimumLockAmount, 'LockToken: token amount must be greater than minimumLockAmount');
        require(token.transferFrom(msg.sender, address(this), _amount),"not support!");
        harvestAll(_forUser);
        token.safeApprove(address(lockContract), _amount);
        lockContract.lock(_forUser, _amount, _lockTokenBlockNumber);
    }

    // Unstake the LQTY and send the it back to the caller, along with their accumulated LUSD & ETH gains. 
    // If requested amount > stake, send their entire stake.
    function unlock(address _forUser, uint256 _lockRecordId) external notStopped {
        require(_forUser != address(0), 'LockToken: _forUser can not be Zero');
        (uint currentStake,) = lockContract.getUserAllStakedToken(_forUser);
        _requireUserHasStake(currentStake);
        
        (,,uint _lockTokenAmount,,,) = lockContract.getLockRecord(_lockRecordId);
        lockToken.safeTransferFrom(msg.sender, address(this), _lockTokenAmount);
        harvestAll(_forUser);
        lockToken.safeApprove(address(lockContract), _lockTokenAmount);
        lockContract.unlock(_forUser,_lockRecordId);
    }
    
    function emergencyUnlock(address _forUser, uint256 _lockRecordId) external{
        require(_forUser != address(0), 'LockToken: _forUser can not be Zero');
        (uint currentStake,) = lockContract.getUserAllStakedToken(_forUser);
        _requireUserHasStake(currentStake);
        
        (,,uint _lockTokenAmount,,,) = lockContract.getLockRecord(_lockRecordId);
        lockToken.safeTransferFrom(msg.sender, address(this), _lockTokenAmount);
        
        lockToken.safeApprove(address(lockContract), _lockTokenAmount);
        lockContract.unlock(_forUser,_lockRecordId);
        emit EmergencyUnlock(msg.sender, _lockRecordId);
    }
    
    function stake(address _forUser, uint256 _tokenAmount) public {
        require(_forUser != address(0), 'LockToken: _forUser can not be Zero');
        _requireNonZeroAmount(_tokenAmount);
        require(_tokenAmount >= minimumLockAmount, 'LockToken: token amount must be greater than minimumLockAmount');
        require(token.transferFrom(msg.sender, address(this), _tokenAmount),"not support!");
        token.safeApprove(address(lockContract), _tokenAmount);
        lockContract.stake(_forUser,_tokenAmount);
    }
    
    function unstake(address _forUser, uint256 _tokenAmount) public {
        require(_forUser != address(0), 'StakingPool: _forUser can not be Zero');
        require(msg.sender != address(0), 'StakingPool: _forUser can not be Zero');
        require(_tokenAmount >= 0, 'StakingPool: token amount must be greater than Zero');
        
        lockToken.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        lockToken.safeApprove(address(lockContract), _tokenAmount);
        lockContract.unstake(_forUser, _tokenAmount);
    }
    // --- Reward-per-unit-staked increase functions. Called by Liquity core contracts ---

    // function increaseF_ETH(uint _ETHFee) external override {
    //     _requireCallerIsTroveManager();
    //     uint ETHFeePerLQTYStaked;
     
    //     if (totalLQTYStaked > 0) {ETHFeePerLQTYStaked = _ETHFee.mul(DECIMAL_PRECISION).div(totalLQTYStaked);}

    //     F_ETH = F_ETH.add(ETHFeePerLQTYStaked); 
    //     emit F_ETHUpdated(F_ETH);
    // }
    
    function harvest(address _forUser,IERC20 rewardToken) public {
        require(_forUser != address(0), 'StakingPool: _forUser can not be Zero');
        require(tokens[rewardToken]," not support!");
        (uint currentStake,) = lockContract.getUserAllStakedToken(msg.sender);
         _requireUserHasStake(currentStake);
         uint reward = 0;
        if (address(rewardToken)!=address(0)){
                     reward  = _getPendingRewardTokenGain(rewardToken ,msg.sender);
        }
         _updateUserSnapshot(msg.sender, rewardToken);
         
         if (address(rewardToken)!=address(0)){
                     rewardToken.transfer(msg.sender, Gains[rewardToken]);
                     emit StakingGainsWithdrawn(msg.sender, rewardToken,reward);
                }
    }
    
    
    function harvestAll(address _forUser) public {
        require(_forUser != address(0), 'StakingPool: _forUser can not be Zero');
       
        for (uint i = 0; i < rewardTokens.length; i++){
            if (address(rewardTokens[i]) != address(0)){
                Gains[rewardTokens[i]] = _getPendingRewardTokenGain(rewardTokens[i] ,_forUser);
            }
            harvest(_forUser, rewardTokens[i]);
        }
    }

    function increaseTokenReward(IERC20 tokenAddress, uint _reward) external notStopped onlyAdmin{
        // _requireCallerIsBorrowerOperations();
        uint tokenRewardPerLockTokenStaked;
        require(!tokens[tokenAddress], "TokenAddress not supported!");
        
        if (totalLockTokenAmount > 0) {
        	tokenRewardPerLockTokenStaked = _reward.mul(DECIMAL_PRECISION).div(totalLockTokenAmount);
        }
        
        tokensRewards[tokenAddress] = tokensRewards[tokenAddress].add(tokenRewardPerLockTokenStaked);
        emit RewardUpdated(tokenAddress, tokensRewards[tokenAddress]);
    }

    // --- Pending reward functions ---

    // function getPendingETHGain(address _user) external view override returns (uint) {
    //     return _getPendingETHGain(_user);
    // }

    // function _getPendingETHGain(address _user) internal view returns (uint) {
    //     uint F_ETH_Snapshot = snapshots[_user].F_ETH_Snapshot;
    //     uint ETHGain = stakes[_user].mul(F_ETH.sub(F_ETH_Snapshot)).div(DECIMAL_PRECISION);
    //     return ETHGain;
    // }

    function getPendingRewardGain(IERC20 _token ,address _user) external view  returns (uint) {
        return _getPendingRewardTokenGain(_token, _user);
    }

    function _getPendingRewardTokenGain( IERC20 _token, address _user) internal view returns (uint) {
        uint tokenSnapshot = userTokenSnapshots[_user][_token];
        uint tokenReward = stakes[_user].mul(tokensRewards[_token].sub(tokenSnapshot)).div(DECIMAL_PRECISION);
        return tokenReward;
    }

    // --- Internal helper functions ---

    function _updateUserSnapshots(address _user) internal {
        for (uint256 i = 0;i < rewardTokens.length; i++){
            if (address(rewardTokens[i] )!= address(0)){
            userTokenSnapshots[_user][rewardTokens[i]] = tokensRewards[rewardTokens[i]];
            emit StakerSnapshotsUpdated(_user, rewardTokens[i], tokensRewards[rewardTokens[i]]);
            }
        }

    }
    function _updateUserSnapshot(address _user, IERC20 rewardToken)internal{
         if (address(rewardToken )!= address(0)){
            userTokenSnapshots[_user][rewardToken] = tokensRewards[rewardToken];
            emit StakerSnapshotsUpdated(_user, rewardToken, tokensRewards[rewardToken]);
            }
    }

    // function _sendETHGainToUser(uint ETHGain) internal {
    //     emit EtherSent(msg.sender, ETHGain);
    //     (bool success, ) = msg.sender.call{value: ETHGain}("");
    //     require(success, "LQTYStaking: Failed to send accumulated ETHGain");
    // }
    
    // --- Account auth functions ---
    function _addRewardToken(IERC20 newToken)external onlyOwner {
        require(address(newToken) != address(0), "Account cannot be zero address");
        rewardTokens.push(newToken);
        tokens[newToken] = true;
    }
    function _delRewardToken(IERC20 delToken)external onlyOwner {
        require(address(delToken) != address(0), "Account cannot be zero address");
        tokens[delToken] = false;
        for (uint256 i = 1; i < rewardTokens.length; i++){
            if (rewardTokens[i] == delToken){
                for ( uint256 j = i; j < rewardTokens.length - 1; j++) {
                    rewardTokens[j] = rewardTokens[j + 1];
                }
                rewardTokens.length - 1;
                break;
            }
        }
    }
    
    function emergencyStop(address payable _to) public onlyOwner {
        if (_to == address(0)) {
            _to = payable(msg.sender);
        }
        
         for (uint i = 0; i < rewardTokens.length; i++){
            if (address(rewardTokens[i])!=address(0)){
                uint addrBalance = rewardTokens[i].balanceOf(address(this));
                if (addrBalance > ZERO) {
                   rewardTokens[i].safeTransfer(_to, addrBalance);
                }  
            }
        }
        stopped = true;
        
        emit EmergencyStop(msg.sender, _to);
    }
    
    // --- 'require' functions ---

    // function _requireCallerIsTroveManager() internal view {
    //     require(msg.sender == troveManagerAddress, "LQTYStaking: caller is not TroveM");
    // }

    // function _requireCallerIsBorrowerOperations() internal view {
    //     require(msg.sender == borrowerOperationsAddress, "LQTYStaking: caller is not BorrowerOps");
    // }

    //  function _requireCallerIsActivePool() internal view {
    //     require(msg.sender == activePoolAddress, "LQTYStaking: caller is not ActivePool");
    // }

    function _requireUserHasStake(uint currentStake) internal pure {  
        require(currentStake > 0, 'Staking: User must have a non-zero stake');  
    }

    function _requireNonZeroAmount(uint _amount) internal pure {
        require(_amount > 0, 'Staking: Amount must be non-zero');
    }

    // receive() external payable {
    //     _requireCallerIsActivePool();
    // }
}
