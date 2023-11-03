pragma solidity 0.8.11;



// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


interface IHandsToken {
  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


// Staking interface which represents a subset of functionalities from the Staking contract.
// Specifically, this interface includes the functions a typical user would interact with.
interface IStaking {
  // Event emitted when a user stakes.
  event Staked(address indexed staker, uint256 amount);

  // Event emitted when a user unstakes.
  event Unstaked(address indexed staker, uint256 amount);

  // Event emitted when a user claims rewards.
  event RewardsClaimed(address indexed staker, uint256 amount);

  //Event emitted when funds are received for staking.
  event ReceivedFundsForStaking(uint256 amount);

  // Function to view the total amount staked in the contract.
  function viewTotalStaked() external view returns (uint256);

  // Function to view the amount staked by a specific address.
  function stakedAmount(address stakerAddress) external view returns (uint256);

  // Function to stake a specific amount of tokens.
  function stake(uint256 amount) external;

  // Function to unstake a specific amount of tokens.
  function unstake(uint256 amount) external;

  // Function to claim staking rewards.
  function claimRewards() external;

  // Function to view the amount of claimable rewards for a specific address.
  function viewClaimableRewards(address stakerAddress) external view returns (uint256);

  // Function to get the amount of funds received for staking in a specific period.
  function getReceivedFundsForStaking() external view returns (uint256);
}

contract Staking is IStaking, ReentrancyGuard {
  IHandsToken private handsToken;
  Bank public bankContract;

  struct Staker {
    uint256 stakedAmount;
    uint256 lastCumulativeRewardRate;
  }

  uint256 public totalStaked;
  uint256 public cumulativeRewardRate;
  uint256 public unclaimedRewards;
  uint256 public totalReceivedFunds;

  mapping(address => Staker) public stakers;
  mapping(address => uint256) public rewards;

  constructor(address _handsTokenAddress) {
    handsToken = IHandsToken(_handsTokenAddress);
  }

  modifier onlyBankContract() {
    require(msg.sender == address(bankContract), "Only bank contract");
    _;
  }

  modifier bankNotInitialized() {
    require(address(bankContract) == address(0), "Bank contract already initialized");
    _;
  }

  function setBankContract(address _bankContractAddress) external bankNotInitialized {
    bankContract = Bank(payable(_bankContractAddress));
  }

  function stake(uint256 amount) external nonReentrant {
    updateRewardsFor(msg.sender);

    if (totalStaked == 0 && unclaimedRewards > 0) {
      rewards[msg.sender] += unclaimedRewards;
      unclaimedRewards = 0;
    }

    bool success = handsToken.transferFrom(msg.sender, address(this), amount);
    require(success, "Transfer failed");

    totalStaked += amount;
    stakers[msg.sender].stakedAmount += amount;

    emit Staked(msg.sender, amount);
  }

  function unstake(uint256 amount) external nonReentrant {
    updateRewardsFor(msg.sender);

    bool success = handsToken.transfer(msg.sender, amount);
    require(success, "Transfer failed");

    totalStaked -= amount;
    stakers[msg.sender].stakedAmount -= amount;

    emit Unstaked(msg.sender, amount);
  }

  function claimRewards() external {
    updateRewardsFor(msg.sender);

    uint256 reward = rewards[msg.sender];
    rewards[msg.sender] = 0;

    bankContract.withdraw(reward, msg.sender);

    emit RewardsClaimed(msg.sender, reward);
  }

  function addReceivedFundsForStaking(uint256 amount) external onlyBankContract {
    if (totalStaked > 0) {
      cumulativeRewardRate += (amount * 1e18) / totalStaked;
    } else {
      unclaimedRewards += amount;
    }

    totalReceivedFunds += amount; // Increment the total received funds

    emit ReceivedFundsForStaking(amount);
  }

  function updateRewardsFor(address stakerAddress) public {
    Staker storage staker = stakers[stakerAddress];

    if (staker.stakedAmount > 0) {
      rewards[stakerAddress] +=
        ((cumulativeRewardRate - staker.lastCumulativeRewardRate) * staker.stakedAmount) /
        1e18;
    }

    staker.lastCumulativeRewardRate = cumulativeRewardRate;
  }

  function viewTotalStaked() external view returns (uint256) {
    return totalStaked;
  }

  function stakedAmount(address stakerAddress) external view returns (uint256) {
    return stakers[stakerAddress].stakedAmount;
  }

  function viewClaimableRewards(address stakerAddress) external view returns (uint256) {
    Staker memory staker = stakers[stakerAddress];

    uint256 claimableRewards = rewards[stakerAddress];
    if (staker.stakedAmount > 0) {
      claimableRewards +=
        ((cumulativeRewardRate - staker.lastCumulativeRewardRate) * staker.stakedAmount) /
        1e18;
    }

    return claimableRewards;
  }

  function getReceivedFundsForStaking() external view returns (uint256) {
    return totalReceivedFunds;
  }
}

//import "hardhat/console.sol";

/**
 * @title Bank contract
 * @dev  from Affiliate contract.
 * Keeps track of received funds and allows for fund withdrawal.
 */
contract Bank is ReentrancyGuard {

  // Instance of the Staking contract
  Staking private immutable stakingContract;

  // Event emitted when funds are received
  event FundsReceived(
    uint256 amount,
    uint256 blockNumber,
    uint256 stakerAmount
  );

  // Only the staking contract can call this function
  modifier onlyStakingContract() {
    require(
      msg.sender == address(stakingContract),
      "Only the staking contract can call this function."
    );
    _;
  }

  // Constructor to set the affiliate contract
  constructor(address _stakingContract) {
    stakingContract = Staking(_stakingContract);
    stakingContract.setBankContract(address(this));
  }

  /**
   * @dev Receive function to handle incoming Ether transactions.
   */
  receive() external payable {
    // You can add any logic here if needed, or just leave it blank.
    // For now, we'll just call the receiveFunds function to handle the incoming funds.
    receiveFunds();
  }

  /**
   * @dev Allows contributors to deposit funds and emits a FundsReceived event
   */
  function receiveFunds() public payable nonReentrant {
    uint256 potFee = msg.value;

    // Add the remaining potFee to the receivedFundsPerBlock
    // Call the addReceivedFundsForStaking function from the Staking contract
    stakingContract.addReceivedFundsForStaking(potFee);

    // Emit the event for fund receipt
    emit FundsReceived(
      msg.value,
      block.number,
      potFee
    );
  }

  /**
   * @dev Allows the affiliate and contract to withdraw funds and emits a Withdrawal event
   * @param amount Amount to withdraw
   */
  function withdraw(uint256 amount, address recipient) external onlyStakingContract nonReentrant {
    require(amount > 0, "Withdrawal amount should be more than zero");
    require(amount <= address(this).balance, "Not enough funds in the contract.");

    // Transfer the funds to the recipient
    payable(recipient).transfer(amount);
  }
}


contract BurnerManager {
  mapping(address => address) private burnerToOwner;
  mapping(address => address) private ownerToBurner;

  function setBurner(address _burner) public {
    require(burnerToOwner[_burner] == address(0), "Burner already has owner.");

    // If the owner already has a burner, clear it
    if (ownerToBurner[msg.sender] != address(0)) {
      address oldBurner = ownerToBurner[msg.sender];
      delete burnerToOwner[oldBurner];
    }

    // Set the new burner
    burnerToOwner[_burner] = msg.sender;
    ownerToBurner[msg.sender] = _burner;
  }

  function getBurner(address _owner) public view returns (address) {
    if (ownerToBurner[_owner] == address(0)) {
      return _owner;
    }
    return ownerToBurner[_owner];
  }

  function getOwner(address _burner) public view returns (address) {
    if (burnerToOwner[_burner] == address(0)) {
      return _burner;
    }
    return burnerToOwner[_burner];
  }

  function fundBurner(uint _value) public payable {
    address payable burner = payable(ownerToBurner[msg.sender]);
    (bool success, ) = burner.call{value: _value}("");
    require(success, "Transfer to burner address failed.");
  }

  //internal function clearBurner(address _burner) internal {
  function clearBurner(address _owner) internal {
    address burner = ownerToBurner[_owner];
    delete burnerToOwner[burner];
    delete ownerToBurner[_owner];
  }
}

//import "hardhat/console.sol";

contract Hands is BurnerManager {
  Bank private bankContract;

  uint public constant BET_MIN = 1e16;
  uint public constant FEE_PERCENTAGE = 5;
  uint public constant MAX_POINTS_PER_ROUND = 3;
  uint public constant MOVE_TIMEOUT = 2 minutes;
  uint public constant TIMEOUT_MARGIN = 15 seconds;

  enum Moves {
    None,
    Rock,
    Paper,
    Scissors
  }
  enum Outcomes {
    None,
    PlayerA,
    PlayerB,
    Draw,
    PlayerALeft,
    PlayerBLeft,
    PlayerATimeout,
    PlayerBTimeout,
    BothTimeout
  }

  constructor(address _bankContractAddress) {
    bankContract = Bank(payable(_bankContractAddress));
  }

  struct Game {
    address payable playerA;
    address payable playerB;
    uint bet;
    bytes32 encrMovePlayerA;
    bytes32 encrMovePlayerB;
    Moves movePlayerA;
    Moves movePlayerB;
    uint round;
    uint pointsA;
    uint pointsB;
  }

  uint private lastGameId;
  mapping(uint => uint) private commitPhaseStart;
  mapping(uint => uint) private revealPhaseStart; // Added to track the time of the first commit
  mapping(uint => Game) private games;
  mapping(address => uint) public playerGame;
  mapping(uint => uint) public waitingPlayers;
  mapping(bytes32 => uint) private passwordGames;

  // Events
  event PlayersMatched(uint indexed gameId, address indexed playerA, address indexed playerB);
  event PlayerRegistered(uint indexed gameId, address indexed playerAddress, bytes32 name);
  event PlayerWaiting(uint indexed gameId, uint bet, address indexed playerAddress, bool first);
  event GameOutcome(uint indexed gameId, Outcomes outcome);
  event MoveCommitted(uint indexed gameId, address indexed playerAddress, uint round);
  event NewRound(uint indexed gameId, uint round, uint pointsA, uint pointsB);
  event MoveRevealed(uint indexed gameId, address indexed playerAddress, Moves move, uint round);
  event PlayerLeft(uint indexed gameId, address indexed playerAddress);
  event PlayerCancelled(uint indexed gameId, address indexed playerAddress);

  // Modifiers
  modifier validBet() {
    require(msg.value >= BET_MIN, "Bet must be at least the minimum bet amount");
    _;
  }
  modifier isNotAlreadyInGame() {
    address sender = getOwner(msg.sender);
    require(playerGame[sender] == 0, "Player already in game");
    _;
  }
  modifier isRegistered(uint gameId) {
    address sender = getOwner(msg.sender);
    //console.log("Sender:", sender);
    require(playerGame[sender] == gameId, "Player not registered");
    _;
  }
  modifier commitPhaseEnded(uint gameId) {
    require(
      (games[gameId].encrMovePlayerA != 0x0 && games[gameId].encrMovePlayerB != 0x0) ||
        (commitPhaseStart[gameId] != 0 &&
          block.timestamp > commitPhaseStart[gameId] + MOVE_TIMEOUT),
      "Commit phase not ended"
    );
    _;
  }
  modifier isCommitPhase(uint gameId) {
      require(
      games[gameId].encrMovePlayerA == 0x0 || games[gameId].encrMovePlayerB == 0x0,
      "Commit phase ended"
      );
    _;

  }
  modifier hasNotRevealed(uint gameId) {
    address sender = getOwner(msg.sender);
    require(
      (sender == games[gameId].playerA && games[gameId].movePlayerA == Moves.None) ||
        (sender == games[gameId].playerB && games[gameId].movePlayerB == Moves.None),
      "Player already revealed"
    );
    _;
  }
  modifier isRevealPhase(uint gameId) {
    require(
      (games[gameId].encrMovePlayerA != 0x0 && games[gameId].encrMovePlayerB != 0x0) ||
        (revealPhaseStart[gameId] != 0 &&
          block.timestamp < revealPhaseStart[gameId] + MOVE_TIMEOUT + TIMEOUT_MARGIN),
      "Is not reveal phase"
    );
    _;
  }
  modifier revealPhaseEnded(uint gameId) {
    require(
      (games[gameId].movePlayerA != Moves.None && games[gameId].movePlayerB != Moves.None) ||
        (revealPhaseStart[gameId] != 0 &&
          block.timestamp > revealPhaseStart[gameId] + MOVE_TIMEOUT + TIMEOUT_MARGIN),
      "Reveal phase not ended"
    );
    _;
  }

  //User functions
  function register() public payable validBet isNotAlreadyInGame returns (uint) {
    return _register(msg.sender, msg.value);
  }

  function registerWithBurner(
    address burner,
    uint256 betAmount
  ) public payable validBet isNotAlreadyInGame {
    uint bet = betAmount;
    uint burnerFundAmount = msg.value - betAmount;

    _register(msg.sender, bet);

    //set and fund burner
    setBurner(burner);
    fundBurner(burnerFundAmount);
  }

  function createPasswordMatch(bytes32 passwordHash) external payable validBet isNotAlreadyInGame {
    _createPasswordMatch(msg.sender, msg.value, passwordHash);
  }

  function createPasswordMatchWithBurner(
    address burner,
    uint256 betAmount,
    bytes32 passwordHash
  ) external payable validBet isNotAlreadyInGame {
    uint bet = betAmount;
    uint burnerFundAmount = msg.value - betAmount;

    _createPasswordMatch(msg.sender, bet, passwordHash);

    //set and fund burner
    setBurner(burner);
    fundBurner(burnerFundAmount);
  }

  function joinPasswordMatch(string memory password) external payable validBet isNotAlreadyInGame {
    bytes32 passwordHash = sha256(abi.encodePacked(password));
    require(passwordGames[passwordHash] > 0, "Game with the given password does not exist");

    uint gameId = passwordGames[passwordHash];

    require(games[gameId].playerB == payable(address(0)), "Game already has two players");
    require(games[gameId].bet == msg.value, "Bet does not match");

    passwordGames[passwordHash] = 0;
    games[gameId].playerB = payable(msg.sender);
    playerGame[msg.sender] = gameId;
    commitPhaseStart[gameId] = block.timestamp;

    emit PlayerWaiting(gameId, games[gameId].bet, msg.sender, false);
    emit PlayersMatched(gameId, games[gameId].playerA, games[gameId].playerB);
  }

  function joinPasswordMatchWithBurner(
    address burner,
    uint256 betAmount,
    string memory password
  ) external payable validBet isNotAlreadyInGame {
    bytes32 passwordHash = sha256(abi.encodePacked(password));
    require(passwordGames[passwordHash] > 0, "Game with the given password does not exist");

    uint gameId = passwordGames[passwordHash];

    require(games[gameId].playerB == payable(address(0)), "Game already has two players");
    require(games[gameId].bet == betAmount, "Bet does not match");

    passwordGames[passwordHash] = 0;
    games[gameId].playerB = payable(msg.sender);
    playerGame[msg.sender] = gameId;
    commitPhaseStart[gameId] = block.timestamp;

    emit PlayerWaiting(gameId, games[gameId].bet, msg.sender, false);
    emit PlayersMatched(gameId, games[gameId].playerA, games[gameId].playerB);

    //set and fund burner
    setBurner(burner);
    fundBurner(msg.value - betAmount);
  }

  function cancel(uint gameId) public {
    Game storage game = games[gameId];
    address sender = getOwner(msg.sender);
    uint bet = game.bet;
    require(game.playerA == sender, "Cannot cancel this game because sender is not player A");
    require(
      game.playerB == payable(address(0)),
      "Cannot cancel this game because player B is already registered"
    );

    emit PlayerCancelled(gameId, sender);

    clearBurner(games[gameId].playerA);
    clearBurner(games[gameId].playerB);
    delete playerGame[game.playerA];
    delete playerGame[game.playerB];
    delete playerGame[sender];
    delete waitingPlayers[game.bet];
    delete games[gameId];

    //transfer funds back to player
    payable(sender).transfer(bet);
  }

  function leave(uint gameId) public isRegistered(gameId) {
    Game storage game = games[gameId];
    address sender = getOwner(msg.sender);
    require(game.playerA == sender || game.playerB == sender, "Not player of this game");

    if (
      (revealPhaseStart[gameId] != 0 &&
        block.timestamp > revealPhaseStart[gameId] + MOVE_TIMEOUT + TIMEOUT_MARGIN) ||
      (commitPhaseStart[gameId] != 0 && block.timestamp > commitPhaseStart[gameId] + MOVE_TIMEOUT + TIMEOUT_MARGIN)
    ) {
      _abruptFinish(gameId);
      return;
    }

    // Pay remaining player
    address remainingPlayer = game.playerA == sender ? game.playerB : game.playerA;
    Outcomes outcome = game.playerA == sender ? Outcomes.PlayerALeft : Outcomes.PlayerBLeft;
    uint total = game.bet * 2;

    emit PlayerLeft(gameId, sender);
    emit GameOutcome(gameId, outcome);

    clearBurner(games[gameId].playerA);
    clearBurner(games[gameId].playerB);
    delete playerGame[game.playerA];
    delete playerGame[game.playerB];
    delete playerGame[sender];
    delete waitingPlayers[game.bet];
    delete games[gameId];

    //transfer funds
    _payWinner(remainingPlayer, sender, total);
  }

  //send the encrypted move to the contract
  function commit(uint gameId, bytes32 encrMove) public isRegistered(gameId) isCommitPhase(gameId) {
    if (
      commitPhaseStart[gameId] != 0 && block.timestamp > commitPhaseStart[gameId] + MOVE_TIMEOUT + TIMEOUT_MARGIN
    ) {
      _abruptFinish(gameId);
      return;
    }
    Game storage game = games[gameId];
    address sender = getOwner(msg.sender);
    require(sender == game.playerA || sender == game.playerB, "Player not in game");
    if (sender == game.playerA) {
      require(game.encrMovePlayerA == 0x0, "Player already committed");
      game.encrMovePlayerA = encrMove;
    } else {
      require(game.encrMovePlayerB == 0x0, "Player already committed");
      game.encrMovePlayerB = encrMove;
    }

    //Check if last player committed
    //If so, start reveal phase
    if (game.encrMovePlayerA != 0x0 && game.encrMovePlayerB != 0x0) {
      revealPhaseStart[gameId] = block.timestamp;
    }

    emit MoveCommitted(gameId, sender, game.round);
  }

  function reveal(
    uint gameId,
    string memory clearMove
  )
    public
    isRegistered(gameId)
    commitPhaseEnded(gameId)
    hasNotRevealed(gameId)
    isRevealPhase(gameId)
    returns (Moves)
  {
    if (
      revealPhaseStart[gameId] != 0 && block.timestamp > revealPhaseStart[gameId] + MOVE_TIMEOUT + TIMEOUT_MARGIN
    ) {
      _abruptFinish(gameId);
      return Moves.None;
    }
    bytes32 encrMove = sha256(abi.encodePacked(clearMove));
    address sender = getOwner(msg.sender);
    Moves move = Moves(getFirstChar(clearMove));

    if (move == Moves.None) {
      revert("Invalid move");
    }
    Game storage game = games[gameId];

    if (sender == game.playerA) {
      require(game.encrMovePlayerA == encrMove, "Encrypted move does not match");
      game.movePlayerA = move;
    } else {
      require(game.encrMovePlayerB == encrMove, "Encrypted move does not match");
      game.movePlayerB = move;
    }

    emit MoveRevealed(gameId, sender, move, game.round);

    // if (firstReveal[gameId] == 0) {
    //     firstReveal[gameId] = block.timestamp;
    // }

    //call getOutcome if both players have revealed their moves
    if (game.movePlayerA != Moves.None && game.movePlayerB != Moves.None) {
      _getOutcome(gameId);
    }

    return move;
  }

  //Private functions
  function _register(address sender, uint bet) internal returns (uint) {
    uint gameId;

    emit PlayerRegistered(gameId, sender, 0x0);

    if (waitingPlayers[bet] != 0) {
      gameId = waitingPlayers[bet];
      waitingPlayers[bet] = 0;
      games[gameId].playerB = payable(sender);
      playerGame[sender] = gameId;
      commitPhaseStart[gameId] = block.timestamp;
      emit PlayersMatched(gameId, games[gameId].playerA, games[gameId].playerB);
    } else {
      lastGameId += 1;
      gameId = lastGameId;
      games[gameId] = Game({
        playerA: payable(sender),
        playerB: payable(address(0)),
        bet: bet,
        encrMovePlayerA: 0x0,
        encrMovePlayerB: 0x0,
        movePlayerA: Moves.None,
        movePlayerB: Moves.None,
        round: 0,
        pointsA: 0,
        pointsB: 0
      });
      playerGame[sender] = gameId;
      waitingPlayers[bet] = gameId;
      emit PlayerWaiting(gameId, bet, sender, true);
    }

    return gameId;
  }

  function _createPasswordMatch(
    address sender,
    uint bet,
    bytes32 passwordHash
  ) internal returns (uint) {
    lastGameId++;
    uint gameId = lastGameId;
    games[gameId] = Game({
      playerA: payable(sender),
      playerB: payable(address(0)),
      bet: bet,
      encrMovePlayerA: 0x0,
      encrMovePlayerB: 0x0,
      movePlayerA: Moves.None,
      movePlayerB: Moves.None,
      round: 0,
      pointsA: 0,
      pointsB: 0
    });
    playerGame[sender] = lastGameId;
    passwordGames[passwordHash] = lastGameId;
    emit PlayerRegistered(lastGameId, sender, passwordHash);
    emit PlayerWaiting(lastGameId, bet, sender, true);
    return gameId;
  }

  function getFirstChar(string memory str) private pure returns (uint) {
    bytes1 firstByte = bytes(str)[0];
    if (firstByte == 0x31) {
      return 1;
    } else if (firstByte == 0x32) {
      return 2;
    } else if (firstByte == 0x33) {
      return 3;
    } else {
      return 0;
    }
  }

  function _handleRound(uint gameId, Outcomes outcome) private {
    Game storage game = games[gameId];

    //update points
    if (outcome == Outcomes.PlayerA) {
      game.pointsA += 1;
    } else if (outcome == Outcomes.PlayerB) {
      game.pointsB += 1;
    }

    game.round += 1;

    emit NewRound(gameId, game.round, game.pointsA, game.pointsB);

    _resetRound(gameId);

    //check if game is over
    if (game.pointsA == MAX_POINTS_PER_ROUND || game.pointsB == MAX_POINTS_PER_ROUND) {
      //get winner
      address payable winner;
      address payable loser;
      if (game.pointsA == MAX_POINTS_PER_ROUND) {
        winner = game.playerA;
        loser = game.playerB;
      } else {
        winner = game.playerB;
        loser = game.playerA;
      }

      emit GameOutcome(gameId, outcome);

      //calculate total
      uint total = game.bet * 2;

      _resetGame(gameId);
      _payWinner(winner, loser, total);

    }
  }

  function _abruptFinish(uint gameId) private {
    //Check who has not revealed or committed
    Game storage game = games[gameId];
    bool playerACommited = game.encrMovePlayerA != 0x0;
    bool playerBCommited = game.encrMovePlayerB != 0x0;
    bool playerARevealed = game.movePlayerA != Moves.None;
    bool playerBRevealed = game.movePlayerB != Moves.None;

    address payable winningPlayer;
    address payable stalledPlayer;
    bool bothStalled = false;

    //if both players have not committed, refund both
    if (!playerACommited && !playerBCommited) {
      winningPlayer = game.playerA;
      stalledPlayer = game.playerB;
      bothStalled = true;
      emit GameOutcome(gameId, Outcomes.BothTimeout);
    } else if (!playerACommited) {
      winningPlayer = game.playerB;
      stalledPlayer = game.playerA;
      emit GameOutcome(gameId, Outcomes.PlayerATimeout);
    } else if (!playerBCommited) {
      winningPlayer = game.playerA;
      stalledPlayer = game.playerB;
      emit GameOutcome(gameId, Outcomes.PlayerBTimeout);
    } else if (!playerARevealed && !playerBRevealed) {
      winningPlayer = game.playerA;
      stalledPlayer = game.playerB;
      bothStalled = true;
      emit GameOutcome(gameId, Outcomes.BothTimeout);
    } else if (!playerARevealed) {
      winningPlayer = game.playerB;
      stalledPlayer = game.playerA;
      emit GameOutcome(gameId, Outcomes.PlayerATimeout);
    } else if (!playerBRevealed) {
      winningPlayer = game.playerA;
      stalledPlayer = game.playerB;
      emit GameOutcome(gameId, Outcomes.PlayerBTimeout);
    }

    //calculate total
    uint total = game.bet * 2;

    //reset game
    _resetGame(gameId);

    if (bothStalled) {
      _refund(winningPlayer, stalledPlayer, total);
    } else {
      _payWinner(winningPlayer, stalledPlayer, total);
    }

  }

  function _getOutcome(
    uint gameId
  ) private isRegistered(gameId) revealPhaseEnded(gameId) {
    Game storage game = games[gameId];
    Outcomes outcome = _computeOutcome(game.movePlayerA, game.movePlayerB);

    _handleRound(gameId, outcome);
  }

  function _computeOutcome(Moves moveA, Moves moveB) private pure returns (Outcomes) {
    if (moveA == moveB) {
      return Outcomes.Draw;
    } else if (
      (moveA == Moves.Rock && moveB == Moves.Scissors) ||
      (moveA == Moves.Paper && moveB == Moves.Rock) ||
      (moveA == Moves.Scissors && moveB == Moves.Paper)
    ) {
      return Outcomes.PlayerA;
    } else {
      return Outcomes.PlayerB;
    }
  }

  function _payWinner(address winner, address loser, uint total) private {
    // Checks
    require(winner != address(0) && loser != address(0), "Invalid addresses");

    // Effects
    uint fee = (total * FEE_PERCENTAGE) / 100; // Calculate the fee
    uint payout = total - fee;

    // Interactions
    // Transfer the fee to the bank contract
    bankContract.receiveFunds{value: fee}();

    // Pay winner
    payable(winner).transfer(payout);
}

  //function _refund similar to _paywinner still takes a fee for bankContract
  function _refund(address payable playerA, address payable playerB, uint total) private {
    uint fee = (total * FEE_PERCENTAGE) / 100; // Calculate the fee
    uint payout = total - fee;

    // Transfer the fee to the bank contract
    bankContract.receiveFunds{value: fee}();

    //Pay players
    payable(playerA).transfer(payout / 2);
    payable(playerB).transfer(payout / 2);
  }

  function _resetGame(uint gameId) private {
    clearBurner(games[gameId].playerA);
    clearBurner(games[gameId].playerB);
    delete playerGame[games[gameId].playerA];
    delete playerGame[games[gameId].playerB];
    delete games[gameId];
    delete commitPhaseStart[gameId];
    delete revealPhaseStart[gameId];
  }

  function _resetRound(uint gameId) private {
    Game storage game = games[gameId];
    game.movePlayerA = Moves.None;
    game.movePlayerB = Moves.None;
    game.encrMovePlayerA = 0x0;
    game.encrMovePlayerB = 0x0;
    commitPhaseStart[gameId] = block.timestamp;
    delete revealPhaseStart[gameId];
  }
}