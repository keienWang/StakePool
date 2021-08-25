// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BaseMath {
    uint constant public DECIMAL_PRECISION = 1e18;
}
/**
 * Based on OpenZeppelin's SafeMath:
 * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol
 *
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable {
    address private _owner;
    mapping(address => bool) public  admin;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        _owner = msg.sender;
        admin[msg.sender] = true;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }
      function setAdmin(address account, bool isTrue) external onlyAdmin {
        admin[account] = isTrue;
    }

    
    modifier onlyAdmin virtual {
        require( admin[msg.sender] || msg.sender == _owner);
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     *
     * NOTE: This function is not safe, as it doesn’t check owner is calling it.
     * Make sure you check it before calling it.
     */
    function _renounceOwnership() internal {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}


contract CheckContract {
    /**
     * Check that the account is an already deployed non-destroyed contract.
     * See: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol#L12
     */
    function checkContract(address _account) internal view {
        require(_account != address(0), "Account cannot be zero address");

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(_account) }
        require(size > 0, "Account code size cannot be zero");
    }
}

interface LockToken{
    struct LockRecord {
        address user;
        uint256 tokenAmount;
        uint256 lockTokenAmount;
        uint256 lockBlockNumber;
        uint256 unlockBlockNumber;
        bool unlocked;
    }
    
        function getUserLockTotal(address user) external returns(uint256);
        function getLockRecord(uint256 _id) view external returns (address, address, uint256, uint256, uint256, uint256, bool);
        function lock(address _forUser, uint256 _amount, uint256 _lockTokenBlockNumber) external returns (uint256 _id) ;
        function unlock(address _forUser,uint256 _lockRecordId) external ;
        function stake(address _forUser, uint256 _tokenAmount) external ;
        function unstake(address _forUser, uint256 _tokenAmount)external;
}

contract TokenStaking is Ownable, CheckContract, BaseMath {
    using SafeMath for uint;

    mapping( address => uint) public stakes;
    uint public stakeTokenTotal;
    IERC20 public stakeToken;
    IERC20 public LpToken;
    uint256 public minimumLockAmount;
    LockToken public lockContractAddress;

    mapping(IERC20 => uint) tokenFee; 
    mapping(IERC20 => bool) tokens;
    
    IERC20[] public rewardTokens;
    
    mapping(address => mapping (uint => bool)) userLockId;
    mapping(address => mapping(IERC20 => uint)) user_token_snapshots;
    
    // mapping(address => IERC20) Tokens;
    // ILQTYToken public lqtyToken;
    // ILUSDToken public lusdToken;
    
    mapping(IERC20 => uint) internal Gains;
    // address public troveManagerAddress;
    // address public borrowerOperationsAddress;
    // address public activePoolAddress;

    // --- Events ---
    event LpTokenAddressSet(IERC20 _lpToken);
    event StakeTokenAddressSet(address _stakeTokenAddress);
    event LOCKContractAddressSet(LockToken _rewardTokenAddress);
    // event TroveManagerAddressSet(address _troveManager);
    // event BorrowerOperationsAddressSet(address _borrowerOperationsAddress);
    // event ActivePoolAddressSet(address _activePoolAddress);

    event StakeChanged(address indexed staker, uint newStake);
    event StakingGainsWithdrawn(address indexed staker, IERC20 _tokenAddress, uint _tokenGain);
    // event F_ETHUpdated(uint _F_ETH);
    event F_RewardUpdated(IERC20 _rewardtokenAddress, uint _F_Token);
    event stakeTokenTotalUpdated(uint _totalStakeTokenStaked);
    event EtherSent(address _account, uint _amount);
    event StakerSnapshotsUpdated(address _staker, IERC20  _token, uint _F_RewardToken);

    // --- Functions ---

    function setAddresses
    (
        address _stakeTokenAddress,
        LockToken _lockAddress,
        IERC20 _lpToken
        
        // address _troveManagerAddress, 
        // address _borrowerOperationsAddress,
        // address _activePoolAddress
    ) 
        external 
        onlyOwner 
         
    {
        checkContract(_stakeTokenAddress);
        checkContract(address(_lockAddress));
        checkContract(address(_lpToken));
       
        // checkContract(_troveManagerAddress);
        // checkContract(_borrowerOperationsAddress);
        // checkContract(_activePoolAddress);

        stakeToken = IERC20(_stakeTokenAddress);
        lockContractAddress = _lockAddress;
        LpToken = _lpToken;
     
        // troveManagerAddress = _troveManagerAddress;
        // borrowerOperationsAddress = _borrowerOperationsAddress;
        // activePoolAddress = _activePoolAddress;

        emit LpTokenAddressSet(_lpToken);
        emit StakeTokenAddressSet(_stakeTokenAddress);
        emit LOCKContractAddressSet(_lockAddress);
       
        // emit TroveManagerAddressSet(_troveManagerAddress);
        // emit BorrowerOperationsAddressSet(_borrowerOperationsAddress);
        // emit ActivePoolAddressSet(_activePoolAddress);

        _renounceOwnership();
    }
     function setMinimumLockQuantity(uint256 _minimumLockAmount) public onlyAdmin {
     
        minimumLockAmount = _minimumLockAmount;
    }


    // If caller has a pre-existing stake, send any accumulated ETH and LUSD gains to them. 
    function lock(address  _forUser, uint256 _amount, uint256 _lockTokenBlockNumber) external  {
        _requireNonZeroAmount(_amount);

        require(_amount >= minimumLockAmount, 'LockToken: token amount must be greater than minimumLockAmount');
        require(stakeToken.transferFrom(_forUser, address(this), _amount),"not support!");
        
        uint currentStake = lockContractAddress.getUserLockTotal(msg.sender);

        // Grab any accumulated ETH and LUSD gains from the current stake
        if (currentStake != 0) {
            for (uint i = 0; i < rewardTokens.length; i++){
                if (address(rewardTokens[i])!=address(0)){
                     Gains[rewardTokens[i]] = _getPendingRewardTokenGain(rewardTokens[i] ,msg.sender);
                }
            }
            
            // ETHGain = _getPendingETHGain(msg.sender);
            // LUSDGain = _getPendingLUSDGain(msg.sender);
        }
    
       _updateUserSnapshots(msg.sender);

        // uint newStake = currentStake.add(_amount);

        // Increase user’s stake and total LQTY staked
        // stakes[msg.sender] = newStake;
        // stakeTokenTotal = stakeTokenTotal.add(_amount);
        // emit stakeTokenTotalUpdated(stakeTokenTotal);

        // Transfer LQTY from caller to this contract
        // lqtyToken.sendToLQTYStaking(msg.sender, _amount);
        lockContractAddress.lock(msg.sender, _amount, _lockTokenBlockNumber);
        // userLockId[msg.sender][lockId] = true;
        // emit StakeChanged(msg.sender, newStake);
        // emit StakingGainsWithdrawn(msg.sender, LUSDGain, ETHGain);

         // Send accumulated LUSD and ETH gains to the caller
        if (currentStake != 0) {
            
            for (uint i = 0; i < rewardTokens.length; i++){
                if (address(rewardTokens[i])!=address(0)){
                     rewardTokens[i].transfer(msg.sender, Gains[rewardTokens[i]]);
                     Gains[rewardTokens[i]] = 0;
                }
            }
        
            // lusdToken.transfer(msg.sender, LUSDGain);
            // _sendETHGainToUser(ETHGain);
        }
    }

    // Unstake the LQTY and send the it back to the caller, along with their accumulated LUSD & ETH gains. 
    // If requested amount > stake, send their entire stake.
    function unlock(uint256 _lockRecordId) external  {
        uint currentStake = lockContractAddress.getUserLockTotal(msg.sender);
        _requireUserHasStake(currentStake);

        // require(userLockId[msg.sender][_lockRecordId],"failed!");

        // userLockId[msg.sender][_lockRecordId] = false;
        // mapping(IERC20 => uint) storage Gains;
        (,,,uint _LptokanAmount,,,) = lockContractAddress.getLockRecord(_lockRecordId);
        require(LpToken.transferFrom(msg.sender, address(this), _LptokanAmount),"transferFrom failed!");
        

        // Grab any accumulated ETH and LUSD gains from the current stake
        if (currentStake != 0) {
            for (uint i = 0; i < rewardTokens.length; i++){
                if (address(rewardTokens[i])!=address(0)){
                     Gains[rewardTokens[i]] = _getPendingRewardTokenGain(rewardTokens[i] ,msg.sender);
                }
            }
            
            // ETHGain = _getPendingETHGain(msg.sender);
            // LUSDGain = _getPendingLUSDGain(msg.sender);
        }
        
        // Grab any accumulated ETH and LUSD gains from the current stake
        // uint ETHGain = _getPendingETHGain(msg.sender);
        // uint LUSDGain = _getPendingLUSDGain(msg.sender);
        
        _updateUserSnapshots(msg.sender);
        
        // (,uint _tokanAmount,,,,) = lockContractAddress.lockRecords(_lockRecordId);
        // if (_tokanAmount > 0) {
            // uint LQTYToWithdraw = LiquityMath._min(_LQTYamount, currentStake);

            // uint newStake = currentStake.sub(_tokanAmount);

            // Decrease user's stake and total LQTY staked
            // stakes[msg.sender] = newStake;
            // stakeTokenTotal = stakeTokenTotal.sub(_tokanAmount);
            // emit stakeTokenTotalUpdated(stakeTokenTotal);

            // Transfer unstaked LQTY to user
            // lqtyToken.transfer(msg.sender, LQTYToWithdraw);
            lockContractAddress.unlock(msg.sender,_lockRecordId);

            // emit StakeChanged(msg.sender, newStake);
        // }


        // Send accumulated LUSD and ETH gains to the caller
        // lusdToken.transfer(msg.sender, LUSDGain);
        // _sendETHGainToUser(ETHGain);
        if (currentStake != 0) {
            for (uint i = 0; i < rewardTokens.length; i++){
                if (address(rewardTokens[i])!=address(0)){
                     rewardTokens[i].transfer(msg.sender, Gains[rewardTokens[i]]);
                     Gains[rewardTokens[i]] = 0;
                     emit StakingGainsWithdrawn(msg.sender, rewardTokens[i],Gains[rewardTokens[i]]);
                }
            }
     
        }
    }
    
    function stake(address _forUser, uint256 _tokenAmount) public {
        _requireNonZeroAmount(_tokenAmount);
        require(_tokenAmount >= minimumLockAmount, 'LockToken: token amount must be greater than minimumLockAmount');
        require(stakeToken.transferFrom(_forUser, address(this), _tokenAmount),"not support!");
        lockContractAddress.stake(_forUser,_tokenAmount);
    }
    
    
    function unstake(uint256 _tokenAmount) public {
        require(msg.sender != address(0), 'LockToken: _forUser can not be Zero');
        require(_tokenAmount >= 0, 'LockToken: token amount must be greater than Zero');
        require(LpToken.transferFrom(msg.sender, address(this), _tokenAmount),"transferFrom failed!");
        lockContractAddress.unstake(msg.sender, _tokenAmount);
    }
    

    // --- Reward-per-unit-staked increase functions. Called by Liquity core contracts ---

    // function increaseF_ETH(uint _ETHFee) external override {
    //     _requireCallerIsTroveManager();
    //     uint ETHFeePerLQTYStaked;
     
    //     if (totalLQTYStaked > 0) {ETHFeePerLQTYStaked = _ETHFee.mul(DECIMAL_PRECISION).div(totalLQTYStaked);}

    //     F_ETH = F_ETH.add(ETHFeePerLQTYStaked); 
    //     emit F_ETHUpdated(F_ETH);
    // }
    
    function harvest(IERC20 rewardToken) public {
        require(tokens[rewardToken]," not support!");
         uint currentStake = lockContractAddress.getUserLockTotal(msg.sender);
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
    
    
    function harvestAll() public {
        uint currentStake = lockContractAddress.getUserLockTotal(msg.sender);
        _requireUserHasStake(currentStake);

        // require(userLockId[msg.sender][_lockRecordId],"failed!");
        // userLockId[msg.sender][_lockRecordId] = false;
        // mapping(IERC20 => uint) storage Gains;
        // (,,,uint _LptokanAmount,,,) = lockContractAddress.getLockRecord(_lockRecordId);
        // require(LpToken.transferFrom(msg.sender, address(this), _LptokanAmount),"transferFrom failed!");
        

        // Grab any accumulated ETH and LUSD gains from the current stake
        if (currentStake != 0) {
            for (uint i = 0; i < rewardTokens.length; i++){
                if (address(rewardTokens[i])!=address(0)){
                     Gains[rewardTokens[i]] = _getPendingRewardTokenGain(rewardTokens[i] ,msg.sender);
                }
            }
            
            // ETHGain = _getPendingETHGain(msg.sender);
            // LUSDGain = _getPendingLUSDGain(msg.sender);
        }
        _updateUserSnapshots(msg.sender);
        
        if (currentStake != 0) {
            for (uint i = 0; i < rewardTokens.length; i++){
                if (address(rewardTokens[i])!=address(0)){
                     rewardTokens[i].transfer(msg.sender, Gains[rewardTokens[i]]);
                     Gains[rewardTokens[i]] = 0;
                     emit StakingGainsWithdrawn(msg.sender, rewardTokens[i],Gains[rewardTokens[i]]);
                }
            }
     
        }
    }

    function increaseF_Token( IERC20 tokenAddress, uint _tokenFee) external  onlyAdmin{
        // _requireCallerIsBorrowerOperations();
        uint TokenFeePerStakeTokenStaked;
        require(!tokens[tokenAddress], "TokenAddress not supported!");
        if (stakeTokenTotal > 0) {TokenFeePerStakeTokenStaked = _tokenFee.mul(DECIMAL_PRECISION).div(stakeTokenTotal);}
        
        tokenFee[tokenAddress] = tokenFee[tokenAddress].add(TokenFeePerStakeTokenStaked);
        emit F_RewardUpdated( tokenAddress, tokenFee[tokenAddress]);
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
        uint F_Token_Snapshot = user_token_snapshots[_user][_token];
        uint LUSDGain = stakes[_user].mul(tokenFee[_token].sub(F_Token_Snapshot)).div(DECIMAL_PRECISION);
        return LUSDGain;
    }

    // --- Internal helper functions ---

    function _updateUserSnapshots(address _user) internal {
        for (uint256 i = 0;i < rewardTokens.length; i++){
            if (address(rewardTokens[i] )!= address(0)){
            user_token_snapshots[_user][rewardTokens[i]] = tokenFee[rewardTokens[i]];
            emit StakerSnapshotsUpdated(_user, rewardTokens[i], tokenFee[rewardTokens[i]]);
            }
        }

    }
    function _updateUserSnapshot(address _user, IERC20 rewardToken)internal{
         if (address(rewardToken )!= address(0)){
            user_token_snapshots[_user][rewardToken] = tokenFee[rewardToken];
            emit StakerSnapshotsUpdated(_user, rewardToken, tokenFee[rewardToken]);
            }
    }

    // function _sendETHGainToUser(uint ETHGain) internal {
    //     emit EtherSent(msg.sender, ETHGain);
    //     (bool success, ) = msg.sender.call{value: ETHGain}("");
    //     require(success, "LQTYStaking: Failed to send accumulated ETHGain");
    // }
    
    // --- Account auth functions ---
    function _addRewardToken(IERC20 newToken)external onlyAdmin {
        require(address(newToken) != address(0), "Account cannot be zero address");
        rewardTokens.push(newToken);
        tokens[newToken] = true;
        
    }
    function _delRewardToken(IERC20 delToken)external onlyAdmin {
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