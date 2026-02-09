import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/game_session.dart';
import 'package:flutter/services.dart';

class GameScreen extends StatefulWidget {
  final String playerId;
  final String playerName;
  final String gameId;
  final bool isHost;
  final WebSocketService webSocketService;

  const GameScreen({
    super.key,
    required this.playerId,
    required this.playerName,
    required this.gameId,
    required this.isHost,
    required this.webSocketService,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final ApiService _apiService = ApiService();
  
  GameSession? _session;
  String _currentPhase = 'waiting';
  bool _isReady = false;
  bool _showRole = false;
  int _readyCount = 0;
  int _totalPlayers = 0;
  bool _hasVoted = false;           
  Map<String, dynamic>? _results;
  List<Map<String, dynamic>> _voteTally = [];
  String? _myVoteId;
  
  // Timer variables
  Timer? _timer;
  int _timeRemaining = 0;
  
  // Game over
  bool _isGameOver = false;
  final TextEditingController _newCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.webSocketService.onMessageReceived = _handleMessage;
    
    if (widget.isHost) {
      _startSession();
    }
  }

  Future<void> _startSession() async {
    await _apiService.startSession(widget.gameId);
  }

  void _startTimer() {
    _timer?.cancel();
    _timeRemaining = _session?.clueTimer ?? 30;
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];
    final data = message['data'] ?? {};

    switch (type) {
      case 'session_started':
        setState(() {
          _session = GameSession.fromJson(data);
          _currentPhase = 'delegation';
          _isReady = false;
          _readyCount = 0;
          _hasVoted = false;
          _myVoteId = null;
          _voteTally = [];
          _results = null;
          _isGameOver = false;
        });
        break;
      
      case 'player_ready_start_changed':
        setState(() {
          _readyCount = data['ready_count'] ?? 0;
          _totalPlayers = data['total_players'] ?? 0;
        });
        break;
      
      case 'clue_phase_started':
        setState(() {
          _currentPhase = 'deception';
          _session?.currentTurn = data['current_turn'];
          _session?.currentTurnId = data['current_turn_id'];
          _isReady = false;
          _readyCount = 0;
        });
        _startTimer();
        break;
      
      case 'next_turn':
        setState(() {
          _session?.currentTurn = data['player_name'];
          _session?.currentTurnId = data['player_id'];
        });
        _startTimer();
        break;
      
      case 'player_ready_changed':
        setState(() {
          _readyCount = data['ready_count'] ?? 0;
          _totalPlayers = data['total_players'] ?? 0;
        });
        break;
      
      case 'clue_phase_complete':
        _timer?.cancel();
        setState(() {
          _currentPhase = 'voting';
          _isReady = false;
          _readyCount = 0;
        });
        break;
      
      case 'vote_update':
        setState(() {
          _readyCount = data['votes_in'] ?? 0;
          _totalPlayers = data['total_players'] ?? 0;
          _voteTally = List<Map<String, dynamic>>.from(data['vote_tally'] ?? []);
        });
        break;

      case 'vote_tie':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'It\'s a tie! Keep voting.'),
            backgroundColor: Colors.orange,
          ),
        );
        break;

      case 'session_results':
        setState(() {
          _results = data;
          _isGameOver = data['game_over'] ?? false;
          _currentPhase = _isGameOver ? 'game_over' : 'results';
        });
        break;
        
      case 'player_quit':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${data['player_name']} left the game'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
        break;

      case 'game_deleted':
        SystemNavigator.pop();
        break;
      
      case 'new_game_started':
        setState(() {
          _currentPhase = 'waiting';
          _session = null;
          _results = null;
          _isGameOver = false;
        });
        if (widget.isHost) {
          _startSession();
        }
        break;
    }
  }

  void _toggleReadyStart() {
    widget.webSocketService.sendMessage({
      'type': 'toggle_ready_start',
      'data': {},
    });
    setState(() => _isReady = !_isReady);
  }

  void _endTurn() {
    _timer?.cancel();
    widget.webSocketService.sendMessage({
      'type': 'end_turn',
      'data': {},
    });
  }

  void _toggleReadyToVote() {
    widget.webSocketService.sendMessage({
      'type': 'toggle_ready',
      'data': {},
    });
    setState(() => _isReady = !_isReady);
  }

  void _submitVote(String playerId) {
    widget.webSocketService.sendMessage({
      'type': 'submit_vote',
      'data': {'vote_for_id': playerId},
    });
    
    setState(() => _myVoteId = playerId);
  }

  void _finalizeVotes() {
    widget.webSocketService.sendMessage({
      'type': 'finalize_votes',
      'data': {},
    });
  }

  void _startNextSession() {
    widget.webSocketService.sendMessage({
      'type': 'start_next_session',
      'data': {},
    });
    
    setState(() {
      _hasVoted = false;
      _isReady = false;
      _readyCount = 0;
      _myVoteId = null;
      _voteTally = [];
      _results = null;
    });
  }

  void _startNewGameSameCategory() {
    widget.webSocketService.sendMessage({
      'type': 'new_game',
      'data': {},
    });
  }

  void _startNewGameNewCategory() {
    if (_newCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a category')),
      );
      return;
    }
    
    widget.webSocketService.sendMessage({
      'type': 'new_game',
      'data': {'category': _newCategoryController.text.trim()},
    });
    
    _newCategoryController.clear();
  }

  bool _hasMajority() {
    if (_voteTally.isEmpty) return false;
    
    int maxVotes = 0;
    int playersWithMax = 0;
    
    for (var player in _voteTally) {
      int votes = player['votes'] ?? 0;
      if (votes > maxVotes) {
        maxVotes = votes;
        playersWithMax = 1;
      } else if (votes == maxVotes && votes > 0) {
        playersWithMax++;
      }
    }
    
    return playersWithMax == 1 && maxVotes > 0;
  }

  void _showQuitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3E),
        title: const Text(
          'Quit Game',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Quitting will remove you from the game and close the app.',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Go Back',
              style: TextStyle(color: Color(0xFF08C8E9)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              widget.webSocketService.sendMessage({
                'type': 'quit_game',
                'data': {},
              });
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
            child: const Text('Quit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Game: ${widget.gameId}',
          style: const TextStyle(color: Color(0xFF08C8E9)),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showQuitDialog,
            icon: const Icon(Icons.exit_to_app, color: Color(0xFFFF5252)),
            tooltip: 'Quit Game',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_session == null && _currentPhase != 'results' && _currentPhase != 'game_over') {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentPhase) {
      case 'delegation':
        return _buildDelegationPhase();
      case 'deception':
        return _buildDeceptionPhase();
      case 'voting':
        return _buildVotingPhase();
      case 'results':
        return _buildResultsPhase();
      case 'game_over':
        return _buildGameOverPhase();
      default:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildDelegationPhase() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Your Role',
            style: TextStyle(fontSize: 22, color: Color(0xFFB0B0B0)),
          ),
          const SizedBox(height: 24),
          
          GestureDetector(
            onLongPressStart: (_) => setState(() => _showRole = true),
            onLongPressEnd: (_) => setState(() => _showRole = false),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _showRole 
                    ? (_session!.isImpostor ? const Color(0xFFFF5252).withOpacity(0.2) : const Color(0xFF08C8E9).withOpacity(0.2))
                    : const Color(0xFF2A2A3E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showRole
                      ? (_session!.isImpostor ? const Color(0xFFFF5252) : const Color(0xFF08C8E9))
                      : const Color(0xFFB0B0B0),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  if (_showRole) ...[
                    Text(
                      _session!.isImpostor ? '🕵️ IMPOSTOR' : '👤 PLAYER',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _session!.isImpostor ? const Color(0xFFFF5252) : const Color(0xFF08C8E9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _session!.isImpostor 
                          ? 'Blend in! Don\'t get caught!' 
                          : 'Secret Word:',
                      style: const TextStyle(fontSize: 18, color: Color(0xFFB0B0B0)),
                    ),
                    if (!_session!.isImpostor) ...[
                      const SizedBox(height: 8),
                      Text(
                        _session!.secretWord ?? '',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      '👆 Hold to reveal',
                      style: TextStyle(fontSize: 24, color: Color(0xFFB0B0B0)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          Text(
            'Ready: $_readyCount / $_totalPlayers',
            style: const TextStyle(fontSize: 18, color: Color(0xFFB0B0B0)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _toggleReadyStart,
            style: _isReady 
                ? ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF08C8E9).withOpacity(0.3),
                    side: const BorderSide(color: Color(0xFF08C8E9), width: 2),
                  )
                : null,
            child: Text(
              _isReady ? 'Ready ✓' : 'I\'m Ready',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeceptionPhase() {
    final isMyTurn = _session?.currentTurnId == widget.playerId;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _timeRemaining <= 5 
                  ? const Color(0xFFFF5252).withOpacity(0.2) 
                  : const Color(0xFF08C8E9).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: _timeRemaining <= 5 
                    ? const Color(0xFFFF5252) 
                    : const Color(0xFF08C8E9),
                width: 2,
              ),
            ),
            child: Text(
              '$_timeRemaining',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _timeRemaining <= 5 
                    ? const Color(0xFFFF5252) 
                    : const Color(0xFF08C8E9),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            isMyTurn ? 'YOUR TURN!' : 'Current Turn:',
            style: TextStyle(
              fontSize: 20,
              color: isMyTurn ? const Color(0xFF08C8E9) : const Color(0xFFB0B0B0),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _session?.currentTurn ?? '',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),

          if (isMyTurn) ...[
            const Text(
              'Give a one-word clue!',
              style: TextStyle(fontSize: 18, color: Color(0xFFB0B0B0)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _endTurn,
              child: const Text('Done'),
            ),
          ] else ...[
            const Text(
              'Listen to the clue...',
              style: TextStyle(fontSize: 18, color: Color(0xFFB0B0B0)),
            ),
            if (widget.isHost) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _skipTurn,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF5252)),
                ),
                child: const Text(
                  'Skip Turn',
                  style: TextStyle(color: Color(0xFFFF5252)),
                ),
              ),
            ],
          ],

          const SizedBox(height: 48),
          Divider(color: const Color(0xFFB0B0B0).withOpacity(0.3)),
          const SizedBox(height: 16),

          Text(
            'Ready to vote: $_readyCount / $_totalPlayers',
            style: const TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _toggleReadyToVote,
            style: _isReady
                ? OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF08C8E9).withOpacity(0.3),
                  )
                : null,
            child: Text(_isReady ? 'Ready to Vote ✓' : 'Ready to Vote'),
          ),
        ],
      ),
    );
  }

  Widget _buildVotingPhase() {
    final canSubmit = _readyCount == _totalPlayers && _hasMajority();
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🗳️ VOTING TIME',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF08C8E9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Votes in: $_readyCount / $_totalPlayers',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
          ),
          if (!_hasMajority() && _voteTally.isNotEmpty)
            const Text(
              '⚠️ Need a majority to submit!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFFFF5252)),
            ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView.builder(
              itemCount: _voteTally.isEmpty 
                  ? _session?.turnOrder.length ?? 0 
                  : _voteTally.length,
              itemBuilder: (context, index) {
                final player = _voteTally.isEmpty
                    ? _session!.turnOrder[index]
                    : null;
                
                final id = _voteTally.isEmpty 
                    ? player!.id 
                    : _voteTally[index]['id'];
                final name = _voteTally.isEmpty 
                    ? player!.name 
                    : _voteTally[index]['name'];
                final votes = _voteTally.isEmpty 
                    ? 0 
                    : _voteTally[index]['votes'];
                
                final isMe = id == widget.playerId;
                final isMyVote = id == _myVoteId;

                return Card(
                  color: isMyVote 
                      ? const Color(0xFF08C8E9).withOpacity(0.15) 
                      : const Color(0xFF2A2A3E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isMyVote 
                        ? const BorderSide(color: Color(0xFF08C8E9), width: 1) 
                        : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: Color(0xFF08C8E9), size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  isMe ? '$name (You)' : name,
                                  style: TextStyle(
                                    color: isMe ? const Color(0xFFB0B0B0) : Colors.white,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$votes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (!isMe) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () => _submitVote(id),
                              style: isMyVote
                                  ? ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF08C8E9),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    )
                                  : ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2A2A3E),
                                      side: const BorderSide(color: Color(0xFF08C8E9)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                              child: Text(
                                isMyVote ? 'Voted' : 'Vote',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isMyVote 
                                      ? const Color(0xFF1A1A2E) 
                                      : const Color(0xFF08C8E9),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          if (widget.isHost)
            ElevatedButton(
              onPressed: canSubmit ? _finalizeVotes : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                foregroundColor: Colors.white,
              ),
              child: Text(
                canSubmit 
                    ? 'Submit Votes' 
                    : _readyCount < _totalPlayers
                        ? 'Waiting for all votes...'
                        : 'Need majority to submit',
              ),
            ),

          if (!widget.isHost)
            const Text(
              'Discuss and vote! Host will submit when ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB0B0B0)),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsPhase() {
    final impostorCaught = _results?['impostor_caught'] ?? false;
    final impostorName = _results?['impostor_name'] ?? 'Unknown';
    final votedOutName = _results?['voted_out_name'] ?? 'No one';
    final players = _results?['players'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: impostorCaught 
                  ? const Color(0xFF08C8E9).withOpacity(0.15) 
                  : const Color(0xFFFF5252).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: impostorCaught 
                    ? const Color(0xFF08C8E9) 
                    : const Color(0xFFFF5252),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  impostorCaught ? '🎉 IMPOSTOR CAUGHT!' : '😈 IMPOSTOR WINS!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: impostorCaught 
                        ? const Color(0xFF08C8E9) 
                        : const Color(0xFFFF5252),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The impostor was: $impostorName',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voted out: $votedOutName',
                  style: const TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Scoreboard',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF08C8E9),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Card(
                  color: const Color(0xFF2A2A3E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF08C8E9),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      player['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      '${player['points']} pts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF08C8E9),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          if (widget.isHost)
            ElevatedButton(
              onPressed: _startNextSession,
              child: const Text('Next Round'),
            ),

          if (!widget.isHost)
            const Text(
              'Waiting for host to start next round...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB0B0B0)),
            ),
        ],
      ),
    );
  }

  Widget _buildGameOverPhase() {
    final players = _results?['players'] as List<dynamic>? ?? [];
    
    final sortedPlayers = List<dynamic>.from(players);
    sortedPlayers.sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));
    
    final winner = sortedPlayers.isNotEmpty ? sortedPlayers[0] : null;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFFD700),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  '🏆 GAME OVER! 🏆',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 16),
                if (winner != null) ...[
                  const Text(
                    'Winner:',
                    style: TextStyle(fontSize: 16, color: Color(0xFFB0B0B0)),
                  ),
                  Text(
                    '${winner['name']}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${winner['points']} points',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF08C8E9),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Final Scores',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF08C8E9),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: sortedPlayers.length,
              itemBuilder: (context, index) {
                final player = sortedPlayers[index];
                return Card(
                  color: index == 0 
                      ? const Color(0xFFFFD700).withOpacity(0.15) 
                      : const Color(0xFF2A2A3E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: index == 0 
                        ? const BorderSide(color: Color(0xFFFFD700), width: 1) 
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index == 0 
                          ? const Color(0xFFFFD700) 
                          : const Color(0xFF08C8E9),
                      child: Text(
                        index == 0 ? '👑' : '${index + 1}',
                        style: TextStyle(
                          color: index == 0 
                              ? Colors.white 
                              : const Color(0xFF1A1A2E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      player['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      '${player['points']} pts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF08C8E9),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          if (widget.isHost) ...[
            ElevatedButton(
              onPressed: _startNewGameSameCategory,
              child: const Text('Play Again (Same Category)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCategoryController,
              decoration: InputDecoration(
                labelText: 'New Category',
                labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
                hintText: 'e.g., Movies, Food, Animals',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF08C8E9)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFB0B0B0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF08C8E9), width: 2),
                ),
                filled: false,
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _startNewGameNewCategory,
              child: const Text('Start New Game'),
            ),
          ],

          if (!widget.isHost)
            const Text(
              'Waiting for host to start a new game...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFB0B0B0)),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.webSocketService.disconnect();
    super.dispose();
  }

  void _skipTurn() {
    widget.webSocketService.sendMessage({
      'type': 'skip_turn',
      'data': {},
    });
  }
}
