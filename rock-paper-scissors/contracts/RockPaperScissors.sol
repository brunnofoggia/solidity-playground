pragma solidity ^0.5.4;

contract RockPaperScissors {
    enum State {
        CREATED,
        JOINED,
        COMMITED,
        REVEALED
    }
    struct Game {
        uint256 id;
        uint256 bet;
        address payable[] players;
        State state;
    }
    struct Move {
        bytes32 hash;
        uint256 value;
    }
    mapping(uint256 => Game) public games;
    mapping(uint256 => mapping(address => Move)) public moves;
    mapping(uint256 => uint256) public winningMoves;
    uint256 public gameId;

    constructor() public {
        winningMoves[1] = 3; // rock
        winningMoves[2] = 1; // paper
        winningMoves[3] = 2; // scissor
    }

    function createGame(address payable participant) external payable {
        require(msg.value > 0, "have to send some ether");
        address payable[] memory players = new address payable[](2);
        players[0] = msg.sender;
        players[1] = participant;

        games[gameId] = Game(gameId, msg.value, players, State.CREATED);
        gameId++;
    }

    function joinGame(uint256 _gameId) external payable {
        Game storage game = games[_gameId];
        require(msg.sender == game.players[1], "sender must be second player");
        require(msg.value >= game.bet, "not enough ether sent");
        require(game.state == State.CREATED, "game must be in CREATED state");
        if (msg.value > game.bet) {
            msg.sender.transfer(msg.value - game.bet);
        }
        game.state = State.JOINED;
    }

    function commitMove(
        uint256 _gameId,
        uint256 moveId,
        uint256 salt
    ) external {
        Game storage game = games[_gameId];
        require(game.state == State.JOINED, "game must be in JOINED state");
        require(
            msg.sender == game.players[0] || msg.sender == game.players[1],
            "can only be called by one of players"
        );
        require(moves[_gameId][msg.sender].hash == 0, "move already made");
        require(
            moveId == 1 || moveId == 2 || moveId == 3,
            "move needs to be 1, 2 or 3"
        );
        moves[_gameId][msg.sender] = Move(
            keccak256(abi.encodePacked(moveId, salt)),
            0
        );
        if (
            moves[_gameId][game.players[0]].hash != 0 &&
            moves[_gameId][game.players[1]].hash != 0
        ) {
            game.state = State.COMMITED;
        }
    }

    function revealMove(
        uint256 _gameId,
        uint256 moveId,
        uint256 salt
    ) external {
        Game storage game = games[_gameId];
        Move storage move1 = moves[_gameId][game.players[0]];
        Move storage move2 = moves[_gameId][game.players[1]];
        Move storage moveSender = moves[_gameId][msg.sender];
        require(game.state == State.COMMITED, "game must be in COMMITED state");
        require(
            msg.sender == game.players[0] || msg.sender == game.players[1],
            "can only be called by one of players"
        );
        require(
            moveSender.hash == keccak256(abi.encodePacked(moveId, salt)),
            "moveId does not match commitment"
        );
        moveSender.value = moveId;
        if (move1.value != 0 && move2.value != 0) {
            if (move1.value == move2.value) {
                game.players[0].transfer(game.bet);
                game.players[1].transfer(game.bet);
                game.state = State.REVEALED;
                return;
            }
            address payable winner;
            winner = winningMoves[move1.value] == move2.value
                ? game.players[0]
                : game.players[1];
            winner.transfer(2 * game.bet);
            game.state = State.REVEALED;
        }
    }
}
