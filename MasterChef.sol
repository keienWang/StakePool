// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./lib.sol";
import "./lockToken.sol";

interface TokenAmountLike {
    // get the token0 amount from the token1 amount
    function getTokenAmount(address _token0, address _token1, uint256 _token1Amount)  external view returns (uint256);
}



// MasterChef is the master of Sushi. He can make Sushi and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once SUSHI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.

contract MasterChef is Ownable, ReentrancyGuard{
    using SafeMath for uint256;
    using SafeMath for uint16;
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of SUSHIs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSushiPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSushiPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract, zero represents mainnet coin pool.
        uint256 amount;     // How many LP tokens the pool has.
        uint256 rewardForEachBlock;    //Reward for each block
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
        uint256 startBlock; // Reward start block.
        uint256 endBlock;  // Reward end block.
        uint256 rewarded;// the total sushi has beed reward, including the dev and user harvest

        uint256 operationFee;// Charged when user operate the pool, only deposit firstly.
        address operationFeeToken;// empty reprsents charged with mainnet token.

        uint16 harvestFeeRatio;// Charged when harvest, div RATIO_BASE for the real ratio, like 100 for 10%
        address harvestFeeToken;// empty reprsents charged with mainnet token.

        bool rewardDev;// if reward dev when reward the farmers.
    }

    uint256 private constant ACC_SUSHI_PRECISION = 1e12;

    uint8 public constant ZERO = 0 ;
    uint16 public constant RATIO_BASE = 1000;

    uint8 public constant DEV1_SUSHI_REWARD_RATIO = 140;// div RATIO_BASE
    uint8 public constant DEV2_SUSHI_REWARD_RATIO = 37;// div RATIO_BASE
    uint8 public constant DEV3_SUSHI_REWARD_RATIO = 23;// div RATIO_BASE
    uint16 public constant MINT_SUSHI_REWARD_RATIO = 800;// div RATIO_BASE

    uint16 public constant DEV1_FEE_RATIO = 500;// div RATIO_BASE
    uint16 public constant DEV2_FEE_RATIO = 250;// div RATIO_BASE
    uint16 public constant DEV3_FEE_RATIO = 250;// div RATIO_BASE

    uint16 public harvestFeeBuyRatio = 900;// the buy ratio for harvest, div RATIO_BASE
    uint16 public harvestFeeDevRatio = 100;// the dev ratio for harvest, div RATIO_BASE

    // The SUSHI TOKEN!
    IERC20 public sushi;
    // Dev address.
    address payable public dev1Address;
    address payable public dev2Address;
    address payable public dev3Address;

    address payable public buyAddress;// address for the fee to buy HKR
    uint256 lockBlockNumber = 864000;
    TokenAmountLike public tokenAmountContract;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    LockToken public lockToken;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyStop(address indexed user, address to);
    event Add(uint256 rewardForEachBlock, IERC20 lpToken, bool withUpdate,
    uint256 startBlock, uint256 endBlock, uint256 operationFee, address operationFeeToken,
    uint16 harvestFeeRatio, address harvestFeeToken, bool withSushiTransfer, bool rewardDev);
    event SetPoolInfo(uint256 pid, uint256 rewardsOneBlock, bool withUpdate, uint256 startBlock, uint256 endBlock, bool rewardDev);
    event ClosePool(uint256 pid, address payable to);
    event UpdateDev1Address(address payable dev1Address);
    event UpdateDev2Address(address payable dev2Address);
    event UpdateDev3Address(address payable dev3Address);
    event UpdateBuyAddress(address payable buyAddress);
    event AddRewardForPool(uint256 pid, uint256 addSushiPerPool, uint256 addSushiPerBlock, bool withSushiTransfer);

    event SetPoolOperationFee(uint256 pid, uint256 operationFee, address operationFeeToken, bool feeUpdate, bool feeTokenUpdate);
    event SetPoolHarvestFee(uint256 pid, uint16 harvestFeeRatio, address harvestFeeToken, bool feeRatioUpdate, bool feeTokenUpdate);

    event SetTokenAmountContract(TokenAmountLike tokenAmountContract);

    event SetHarvestFeeRatio(uint16 harvestFeeBuyRatio, uint16 harvestFeeDevRatio);

    modifier validatePoolByPid(uint256 _pid) {
        require(_pid < poolInfo .length, "Pool does not exist");
        _;
    }

    constructor(
        IERC20 _sushi,
        address payable _dev1Address,
        address payable _dev2Address,
        address payable _dev3Address,
        address payable _buyAddress,
        TokenAmountLike _tokenAmountContract,
        LockToken _lockToken
    )  {
        sushi = _sushi;
        dev1Address = _dev1Address;
        dev2Address = _dev2Address;
        dev3Address = _dev3Address;
        buyAddress = _buyAddress;
        tokenAmountContract = _tokenAmountContract;
        lockToken = _lockToken;
        }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    function setLockBlockNumber(uint256 _lockBlockNumber)external onlyOwner{
        lockBlockNumber = _lockBlockNumber;
    }

    function setTokenAmountContract(TokenAmountLike _tokenAmountContract) external onlyOwner {
        require(_tokenAmountContract != TokenAmountLike(address(0)), "tokenAmountContract can not be zero!");
        tokenAmountContract = _tokenAmountContract;
        emit SetTokenAmountContract(_tokenAmountContract);
    }

    // Update the harvest fee ratio
    function setHarvestFeeRatio(uint16 _harvestFeeBuyRatio, uint16 _harvestFeeDevRatio) external onlyOwner {
        require((_harvestFeeBuyRatio.add(_harvestFeeDevRatio)) == RATIO_BASE, "The sum must be 1000!");
        harvestFeeBuyRatio = _harvestFeeBuyRatio;
        harvestFeeDevRatio = _harvestFeeDevRatio;
        emit SetHarvestFeeRatio(_harvestFeeBuyRatio, _harvestFeeDevRatio);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // Zero lpToken represents mainnet coin pool.
    function add(uint256 _rewardForEachBlock, IERC20 _lpToken, bool _withUpdate,
        uint256 _startBlock, uint256 _endBlock, uint256 _operationFee, address _operationFeeToken,
        uint16 _harvestFeeRatio, address _harvestFeeToken, bool _withSushiTransfer, bool _rewardDev) external onlyOwner {
        //require(_lpToken != IERC20(ZERO), "lpToken can not be zero!");
        require(_rewardForEachBlock > ZERO, "rewardForEachBlock must be greater than zero!");
        require(_startBlock < _endBlock, "start block must less than end block!");
        if (_withUpdate) {
            massUpdatePools();
        }
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            amount: ZERO,
            rewardForEachBlock: _rewardForEachBlock,
            lastRewardBlock: block.number > _startBlock ? block.number : _startBlock,
            accSushiPerShare: ZERO,
            startBlock: _startBlock,
            endBlock: _endBlock,
            rewarded: ZERO,
            operationFee: _operationFee,
            operationFeeToken: _operationFeeToken,
            harvestFeeRatio: _harvestFeeRatio,
            harvestFeeToken: _harvestFeeToken,
            rewardDev: _rewardDev
        }));
        if(_withSushiTransfer){
            uint256 amount = (_endBlock - (block.number > _startBlock ? block.number : _startBlock)).mul(_rewardForEachBlock);
            sushi.safeTransferFrom(msg.sender, address(this), amount);
        }
        emit Add(_rewardForEachBlock, _lpToken, _withUpdate, _startBlock, _endBlock, _operationFee, _operationFeeToken, _harvestFeeRatio, _harvestFeeToken, _withSushiTransfer, _rewardDev);
    }

    // Update the given pool's pool info. Can only be called by the owner.
    function setPoolInfo(uint256 _pid, uint256 _rewardForEachBlock, bool _withUpdate, uint256 _startBlock, uint256 _endBlock, bool _rewardDev) external validatePoolByPid(_pid) onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfo[_pid];
        if(_startBlock > ZERO){
            if(_endBlock > ZERO){
                require(_startBlock < _endBlock, "start block must less than end block!");
            }else{
                require(_startBlock < pool.endBlock, "start block must less than end block!");
            }
            pool.startBlock = _startBlock;
        }
        if(_endBlock > ZERO){
            if(_startBlock <= ZERO){
                require(pool.startBlock < _endBlock, "start block must less than end block!");
            }
            pool.endBlock = _endBlock;
        }
        if(_rewardForEachBlock > ZERO){
            pool.rewardForEachBlock = _rewardForEachBlock;
        }
        pool.rewardDev = _rewardDev;
        emit SetPoolInfo(_pid, _rewardForEachBlock, _withUpdate, _startBlock, _endBlock, _rewardDev);
    }

    function setAllPoolOperationFee(uint256 _operationFee, address _operationFeeToken, bool _feeUpdate, bool _feeTokenUpdate) external onlyOwner {
        uint256 length = poolInfo.length;
        for (uint256 pid = ZERO; pid < length; ++ pid) {
            setPoolOperationFee(pid, _operationFee, _operationFeeToken, _feeUpdate, _feeTokenUpdate);
        }
    }

    // Update the given pool's operation fee
    function setPoolOperationFee(uint256 _pid, uint256 _operationFee, address _operationFeeToken, bool _feeUpdate, bool _feeTokenUpdate) public validatePoolByPid(_pid) onlyOwner {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        if(_feeUpdate){
            pool.operationFee = _operationFee;
        }
        if(_feeTokenUpdate){
            pool.operationFeeToken = _operationFeeToken;
        }
        emit SetPoolOperationFee(_pid, _operationFee, _operationFeeToken, _feeUpdate, _feeTokenUpdate);
    }

    function setAllPoolHarvestFee(uint16 _harvestFeeRatio, address _harvestFeeToken, bool _feeRatioUpdate, bool _feeTokenUpdate) external onlyOwner {
        uint256 length = poolInfo.length;
        for (uint256 pid = ZERO; pid < length; ++ pid) {
            setPoolHarvestFee(pid, _harvestFeeRatio, _harvestFeeToken, _feeRatioUpdate, _feeTokenUpdate);
        }
    }

    // Update the given pool's harvest fee
    function setPoolHarvestFee(uint256 _pid, uint16 _harvestFeeRatio, address _harvestFeeToken, bool _feeRatioUpdate, bool _feeTokenUpdate) public validatePoolByPid(_pid) onlyOwner {
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        if(_feeRatioUpdate){
        	pool.harvestFeeRatio = _harvestFeeRatio;
        }

        if(_feeTokenUpdate){
        	pool.harvestFeeToken = _harvestFeeToken;
        }
        emit SetPoolHarvestFee(_pid, _harvestFeeRatio, _harvestFeeToken, _feeRatioUpdate, _feeTokenUpdate);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        if(_to > _from){
            return _to.sub(_from);
        }
        return ZERO;
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (block.number < pool.startBlock){
            return;
        }
        if (pool.lastRewardBlock >= pool.endBlock){
             return;
        }
        if (pool.lastRewardBlock < pool.startBlock) {
            pool.lastRewardBlock = pool.startBlock;
        }
        uint256 multiplier;
        if (block.number > pool.endBlock){
            multiplier = getMultiplier(pool.lastRewardBlock, pool.endBlock);
            pool.lastRewardBlock = pool.endBlock;
        }else{
            multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            pool.lastRewardBlock = block.number;
        }
        uint256 lpSupply = pool.amount;
        if (lpSupply <= ZERO) {
            return;
        }
        uint256 sushiReward = multiplier.mul(pool.rewardForEachBlock);
        if(sushiReward > ZERO){
            uint256 poolSushiReward = sushiReward;
            if(pool.rewardDev){
                transferToDev(pool, dev1Address, DEV1_SUSHI_REWARD_RATIO, sushiReward);
                transferToDev(pool, dev2Address, DEV2_SUSHI_REWARD_RATIO, sushiReward);
                transferToDev(pool, dev3Address, DEV3_SUSHI_REWARD_RATIO, sushiReward);
                poolSushiReward = sushiReward.mul(MINT_SUSHI_REWARD_RATIO).div(RATIO_BASE);
            }
            pool.accSushiPerShare = pool.accSushiPerShare.add(poolSushiReward.mul(ACC_SUSHI_PRECISION).div(lpSupply));
        }
    }

    function transferToDev(PoolInfo storage _pool, address _devAddress, uint16 _devRatio, uint256 _sushiReward) private returns (uint256 amount){
        if(_devRatio > ZERO){
            amount = _sushiReward.mul(_devRatio).div(RATIO_BASE);
            safeTransferTokenFromThis(sushi, _devAddress, amount);
            _pool.rewarded = _pool.rewarded.add(amount);
        }
    }

    // View function to see pending SUSHIs on frontend.
    function pendingSushi(uint256 _pid, address _user) public view validatePoolByPid(_pid) returns (uint256 sushiReward, uint256 fee) {
        PoolInfo storage pool =  poolInfo[_pid];
        if(_user == address(0)){
            _user = msg.sender;
        }
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSushiPerShare = pool.accSushiPerShare;
        uint256 lpSupply = pool.amount;
        uint256 lastRewardBlock = pool.lastRewardBlock;
        if (lastRewardBlock < pool.startBlock) {
            lastRewardBlock = pool.startBlock;
        }
        if (block.number > lastRewardBlock && block.number >= pool.startBlock && lastRewardBlock < pool.endBlock && lpSupply > ZERO){
            uint256 multiplier = ZERO;
            if (block.number > pool.endBlock){
                multiplier = getMultiplier(lastRewardBlock, pool.endBlock);
            }else{
                multiplier = getMultiplier(lastRewardBlock, block.number);
            }
            uint256 poolSushiReward = multiplier.mul(pool.rewardForEachBlock).mul(MINT_SUSHI_REWARD_RATIO).div(RATIO_BASE);
            accSushiPerShare = accSushiPerShare.add(poolSushiReward.mul(ACC_SUSHI_PRECISION).div(lpSupply));
        }
        sushiReward = user.amount.mul(accSushiPerShare).div(ACC_SUSHI_PRECISION).sub(user.rewardDebt);

        fee = getHarvestFee(pool, sushiReward);
    }

    function getHarvestFee(PoolInfo storage _pool, uint256 _sushiAmount) private view returns (uint256){
        uint256 fee = ZERO;
        if(_pool.harvestFeeRatio > ZERO && tokenAmountContract != TokenAmountLike(address(0))){//charge for fee
            fee = tokenAmountContract.getTokenAmount(_pool.harvestFeeToken, address(sushi), _sushiAmount).mul(_pool.harvestFeeRatio).div(RATIO_BASE);
        }
        return fee;
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = ZERO; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Deposit LP tokens to MasterChef for SUSHI allocation.
    function deposit(uint256 _pid, uint256 _amount) external validatePoolByPid(_pid) payable {
        PoolInfo storage pool = poolInfo[_pid];
        require(block.number <= pool.endBlock, "this pool is end!");
        require(block.number >= pool.startBlock, "this pool is not start!");
        if(pool.lpToken == IERC20(address(0))){//if pool is mainnet coin
            require((_amount + pool.operationFee) == msg.value, "msg.value must be equals to amount + operation fee!");
        }
        checkOperationFee(pool, _amount);
        UserInfo storage user = userInfo[_pid][msg.sender];
        harvest(_pid, msg.sender);
        if(pool.lpToken != IERC20(address(0))){
            pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        }
        pool.amount = pool.amount.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accSushiPerShare).div(ACC_SUSHI_PRECISION);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function checkOperationFee(PoolInfo storage _pool, uint256 _amount) private nonReentrant {
        if(_pool.operationFee > ZERO){// charge for fee
            uint256 dev1Amount = _pool.operationFee.mul(DEV1_FEE_RATIO).div(RATIO_BASE);
            uint256 dev2Amount = _pool.operationFee.mul(DEV2_FEE_RATIO).div(RATIO_BASE);
            uint256 dev3Amount = _pool.operationFee.sub(dev1Amount).sub(dev2Amount);
            if(isMainnetToken(_pool.operationFeeToken)){
                if(_pool.lpToken != IERC20(address(0))){
                    require(msg.value == _pool.operationFee, "Fee is not enough or too much!");
                }else{//if pool is mainnet coin
                    require((msg.value.sub(_amount)) == _pool.operationFee, "Fee is not enough or too much!");
                }
                dev1Address.transfer(dev1Amount);
                dev2Address.transfer(dev2Amount);
                dev3Address.transfer(dev3Amount);
            }else{
                IERC20 token = IERC20(_pool.operationFeeToken);
                uint feeBalance = token.balanceOf(msg.sender);
                require(feeBalance >= _pool.operationFee, "Fee is not enough!");

                token.safeTransferFrom(msg.sender, address(this), _pool.operationFee);

                token.safeTransfer(dev1Address, dev1Amount);
                token.safeTransfer(dev2Address, dev2Amount);
                token.safeTransfer(dev3Address, dev3Amount);
            }
        }
    }

    function isMainnetToken(address _token) private pure returns (bool) {
        return _token == address(0);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external validatePoolByPid(_pid) payable {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(block.number >= pool.startBlock,"this pool is not start!");
        require(user.amount >= _amount, "withdraw: not good");
        harvest(_pid, msg.sender);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accSushiPerShare).div(ACC_SUSHI_PRECISION);
        pool.amount = pool.amount.sub(_amount);
        if (pool.lpToken != IERC20(address(0))) {
            pool.lpToken.safeTransfer(msg.sender, _amount);
        } else {//if pool is mainnet coin
            transferMainnetToken(payable(msg.sender), _amount);
        }
        emit Withdraw(msg.sender, _pid, _amount);
    }

    //transfer mainnet coin
    function transferMainnetToken(address payable _to, uint256 _amount) internal nonReentrant {
        _to.transfer(_amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.amount = pool.amount.sub(user.amount);
        uint256 oldAmount = user.amount;
        user.amount = ZERO;
        user.rewardDebt = ZERO;
        if (pool.lpToken != IERC20(address(0))) {
            pool.lpToken.safeTransfer(msg.sender, oldAmount);
        } else {//if pool is mainnet coin
            transferMainnetToken(payable(msg.sender), oldAmount);
        }
        emit EmergencyWithdraw(msg.sender, _pid, oldAmount);
    }

    function harvest(uint256 _pid, address _to) public nonReentrant payable validatePoolByPid(_pid) returns (bool success) {
        if(_to == address(0)){
            _to = msg.sender;
        }
        PoolInfo storage pool =  poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_to];
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSushiPerShare).div(ACC_SUSHI_PRECISION).sub(user.rewardDebt);
        if (pending > ZERO) {
            success = true;
            checkHarvestFee(pool, pending);
            // safeTransferTokenFromThis(sushi, _to, pending);
            lockToken.lock(_to, pending, lockBlockNumber);
            pool.rewarded = pool.rewarded.add(pending);
            user.rewardDebt = user.amount.mul(pool.accSushiPerShare).div(ACC_SUSHI_PRECISION);
        } else{
            success = false;
        }
        emit Harvest(_to, _pid, pending);
    }

    function checkHarvestFee(PoolInfo storage _pool, uint256 _sushiReward) private {
        uint256 fee = getHarvestFee(_pool, _sushiReward);
        if(fee > ZERO){
            uint256 devFee = fee.mul(harvestFeeDevRatio).div(RATIO_BASE);
            uint256 buyFee = fee.sub(devFee);

            uint256 dev1Amount = devFee.mul(DEV1_FEE_RATIO).div(RATIO_BASE);
            uint256 dev2Amount = devFee.mul(DEV2_FEE_RATIO).div(RATIO_BASE);
            uint256 dev3Amount = devFee.sub(dev1Amount).sub(dev2Amount);

            if(isMainnetToken(_pool.harvestFeeToken)){
                require(msg.value == fee, "Fee is not enough or too much!");
                dev1Address.transfer(dev1Amount);
                dev2Address.transfer(dev2Amount);
                dev3Address.transfer(dev3Amount);
                buyAddress.transfer(buyFee);
            }else{
                IERC20 token = IERC20(_pool.harvestFeeToken);
                uint feeBalance = token.balanceOf(msg.sender);
                require(feeBalance >= fee, "Fee is not enough!");
                token.safeTransferFrom(msg.sender, address(this), fee);

                token.safeTransfer(dev1Address, dev1Amount);
                token.safeTransfer(dev2Address, dev2Amount);
                token.safeTransfer(dev3Address, dev3Amount);
                token.safeTransfer(buyAddress, buyFee);
            }
        }
    }

    function emergencyStop(address payable _to) public onlyOwner {
        if(_to == address(0)){
            _to = payable(msg.sender);
        }
        uint addrBalance = sushi.balanceOf(address(this));
        if(addrBalance > ZERO){
            sushi.safeTransfer(_to, addrBalance);
        }
        uint256 length = poolInfo.length;
        for (uint256 pid = ZERO; pid < length; ++ pid) {
            closePool(pid, _to);
        }
        emit EmergencyStop(msg.sender, _to);
    }

    function closePool(uint256 _pid, address payable _to) public validatePoolByPid(_pid) onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.endBlock = block.number;
        if(_to == address(0)){
            _to = payable(msg.sender);
        }
        emit ClosePool(_pid, _to);
    }

    // Safe transfer token function, just in case if rounding error causes pool to not have enough tokens.
    function safeTransferTokenFromThis(IERC20 _token, address _to, uint256 _amount) internal {
        uint256 bal = _token.balanceOf(address(this));
        if (_amount > bal) {
            _token.safeTransfer(_to, bal);
        } else {
            _token.safeTransfer(_to, _amount);
        }
    }

     // Update dev1 address by the previous dev.
    function updateDev1Address(address payable _dev1Address) external {
        require(msg.sender == dev1Address, "dev1: wut?");
        require(_dev1Address != address(0), "address can not be zero!");
        dev1Address = _dev1Address;
        emit UpdateDev1Address(_dev1Address);
    }

    // Update dev2 address by the previous dev.
    function updateDev2Address(address payable _dev2Address) external {
        require(msg.sender == dev2Address, "dev2: wut?");
        require(_dev2Address != address(0), "address can not be zero!");
        dev2Address = _dev2Address;
        emit UpdateDev2Address(_dev2Address);
    }

    // Update dev3 address by the previous dev.
    function updateDev3Address(address payable _dev3Address) external {
        require(msg.sender == dev3Address, "dev3: wut?");
        require(_dev3Address != address(0), "address can not be zero!");
        dev3Address = _dev3Address;
        emit UpdateDev3Address(_dev3Address);
    }

    // Update dev3 address by the previous dev.
    function updateBuyAddress(address payable _buyAddress) external {
        require(msg.sender == buyAddress, "buyAddress: wut?");
        require(_buyAddress != address(0), "address can not be zero!");
        buyAddress = _buyAddress;
        emit UpdateBuyAddress(_buyAddress);
    }

    // Add reward for pool from the current block or start block
    function addRewardForPool(uint256 _pid, uint256 _addSushiPerPool, uint256 _addSushiPerBlock, bool _withSushiTransfer) external validatePoolByPid(_pid) onlyOwner {
        require(_addSushiPerPool > ZERO || _addSushiPerBlock > ZERO, "add sushi must be greater than zero!");
        PoolInfo storage pool = poolInfo[_pid];
        require(block.number < pool.endBlock, "this pool is going to be end or end!");
        updatePool(_pid);
        uint256 addSushiPerBlock = _addSushiPerBlock;
        uint256 addSushiPerPool = _addSushiPerPool;
        uint256 start = block.number;
        uint256 end = pool.endBlock;
        if(start < pool.startBlock){
            start = pool.startBlock;
        }
        uint256 blockNumber = end.sub(start);
        if(blockNumber <= ZERO){
            blockNumber = 1;
        }
        if(addSushiPerBlock <= ZERO){
            addSushiPerBlock = _addSushiPerPool.div(blockNumber);
        }
        addSushiPerPool = addSushiPerBlock.mul(blockNumber);
        pool.rewardForEachBlock = pool.rewardForEachBlock.add(addSushiPerBlock);
        if(_withSushiTransfer){
            sushi.safeTransferFrom(msg.sender, address(this), addSushiPerPool);
        }
        emit AddRewardForPool(_pid, addSushiPerPool, addSushiPerBlock, _withSushiTransfer);
    }
}
