import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../models/game_session.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game: ${widget.gameId}'),
        automaticallyImplyLeading: false,
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
            style: TextStyle(fontSize: 24, color: Colors.grey),
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
                    ? (_session!.isImpostor ? Colors.red.shade100 : Colors.green.shade100)
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (_showRole) ...[
                    Text(
                      _session!.isImpostor ? '🕵️ IMPOSTOR' : '👤 PLAYER',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _session!.isImpostor ? Colors.red : Colors.green,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _session!.isImpostor 
                          ? 'Blend in! Don\'t get caught!' 
                          : 'Secret Word:',
                      style: const TextStyle(fontSize: 18),
                    ),
                    if (!_session!.isImpostor) ...[
                      const SizedBox(height: 8),
                      Text(
                        _session!.secretWord ?? '',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ] else ...[
                    const Text(
                      '👆 Hold to reveal',
                      style: TextStyle(fontSize: 24, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          Text(
            'Ready: $_readyCount / $_totalPlayers',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _toggleReadyStart,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              backgroundColor: _isReady ? Colors.green : null,
            ),
            child: Text(
              _isReady ? 'Ready ✓' : 'I\'m Ready',
              style: const TextStyle(fontSize: 18),
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
              color: _timeRemaining <= 5 ? Colors.red.shade100 : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$_timeRemaining',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: _timeRemaining <= 5 ? Colors.red : Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            isMyTurn ? 'YOUR TURN!' : 'Current Turn:',
            style: TextStyle(
              fontSize: 20,
              color: isMyTurn ? Colors.orange : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _session?.currentTurn ?? '',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),

          if (isMyTurn) ...[
            const Text(
              'Give a one-word clue!',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _endTurn,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 20)),
            ),
          ] else ...[
            const Text(
              'Listen to the clue...',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],

          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 16),

          Text(
            'Ready to vote: $_readyCount / $_totalPlayers',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _toggleReadyToVote,
            style: OutlinedButton.styleFrom(
              backgroundColor: _isReady ? Colors.green.shade100 : null,
            ),
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
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Votes in: $_readyCount / $_totalPlayers',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (!_hasMajority() && _voteTally.isNotEmpty)
            const Text(
              '⚠️ Need a majority to submit!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.orange),
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
                  color: isMyVote ? Colors.blue.shade50 : null,
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(name),
                    subtitle: isMe ? const Text('(You)') : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$votes',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isMe)
                          ElevatedButton(
                            onPressed: () => _submitVote(id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isMyVote ? Colors.blue : null,
                            ),
                            child: Text(isMyVote ? 'Voted' : 'Vote'),
                          ),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
              ),
              child: Text(
                canSubmit 
                    ? 'Submit Votes' 
                    : _readyCount < _totalPlayers
                        ? 'Waiting for all votes...'
                        : 'Need majority to submit',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

          if (!widget.isHost)
            const Text(
              'Discuss and vote! Host will submit when ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
              color: impostorCaught ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  impostorCaught ? '🎉 IMPOSTOR CAUGHT!' : '😈 IMPOSTOR WINS!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: impostorCaught ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'The impostor was: $impostorName',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voted out: $votedOutName',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          const Text(
            'Scoreboard',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final player = players[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(player['name']),
                    trailing: Text(
                      '${player['points']} pts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Next Round', style: TextStyle(fontSize: 18)),
            ),

          if (!widget.isHost)
            const Text(
              'Waiting for host to start next round...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildGameOverPhase() {
    final players = _results?['players'] as List<dynamic>? ?? [];
    
    // Sort players by points to find winner
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
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  '🏆 GAME OVER! 🏆',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(height: 16),
                if (winner != null) ...[
                  const Text(
                    'Winner:',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  Text(
                    '${winner['name']}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${winner['points']} points',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Final Scores',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: sortedPlayers.length,
              itemBuilder: (context, index) {
                final player = sortedPlayers[index];
                return Card(
                  color: index == 0 ? Colors.amber.shade50 : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: index == 0 ? Colors.amber : null,
                      child: Text(index == 0 ? '👑' : '${index + 1}'),
                    ),
                    title: Text(player['name']),
                    trailing: Text(
                      '${player['points']} pts',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Play Again (Same Category)',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCategoryController,
              decoration: const InputDecoration(
                labelText: 'New Category',
                border: OutlineInputBorder(),
                hintText: 'e.g., Movies, Food, Animals',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _startNewGameNewCategory,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Start New Game',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],

          if (!widget.isHost)
            const Text(
              'Waiting for host to start a new game...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
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
}
