import asyncio
from contextlib import asynccontextmanager
from models import GamePhase
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware 
from game_manager import register_player, create_game,join_game, start_game, start_session, active_games, submit_vote, end_session, quit_game, cleanup_inactive_games, update_activity, rejoin_game
from connection_manager import ConnectionManager
import os


@asynccontextmanager
async def lifespan(app):
    task = asyncio.create_task(cleanup_loop())
    yield
    task.cancel()

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)


manager = ConnectionManager()

@app.post("/player/register")
def register_player_endpoint(name:str):
    player_id = register_player(name)
    return {"player_id": player_id}

@app.post("/game/create")
def create_game_endpoint(host_id: str, max_round: int, clue_time: int, secret_category: str, passcode: str = ""):
    if secret_category and passcode != os.environ.get("CATEGORY_PASSCODE", ""):
        return {"error": "Invalid passcode for custom category"}
    game_id = create_game(host_id, max_round, clue_time, secret_category)
    return {"game_id": game_id}


async def cleanup_loop():
    while True:
        await asyncio.sleep(60)  # Check every minute
        deleted = cleanup_inactive_games(5)
        for game_id in deleted:
            await manager.broadcast_to_game(game_id, {
                "type": "game_deleted",
                "data": {"reason": "Game timed out due to inactivity"}
            })
            # Clean up connections
            if game_id in manager.active_connections:
                del manager.active_connections[game_id]

@app.post("/game/join")
async def join_game_endpoint(player_id: str, game_id: str):
    success = join_game(player_id, game_id)
    if success:
        # Get the player's name to broadcast
        from game_manager import active_players
        player = active_players.get(player_id)
        player_name = player.name if player else "Unknown"
        
        # Broadcast to everyone in the game
        await manager.broadcast_to_game(game_id, {
            "type": "player_joined",
            "data": {
                "player_id": player_id,
                "name": player_name
            }
        })
        
        # Return current player list
        game = active_games[game_id]
        players = [{"id": p.id, "name": p.name} for p in game.loPlayers]
        return {"message": "Successfully joined the game", "players": players}
    else:
        return {"message": "Game not found"}

@app.post("/game/rejoin")
async def rejoin_game_endpoint(game_id: str, player_id: str):
    result = rejoin_game(game_id, player_id)
    
    if result["status"] == "success":
        # Re-establish WebSocket will happen separately when client connects
        return result
    else:
        return result

@app.post("/game/start")
async def start_game_endpoint(game_id: str):
    success = start_game(game_id)
    if success:
        await manager.broadcast_to_game(game_id, {
            "type": "game_started",
            "data": {"game_id": game_id}
        })
        return {"message": "Successfully started the game"}
    else:
        return {"message": "Game not found"}

@app.post("/session/start")
async def session_start_endpoint(game_id: str):
    success = start_session(game_id)
    if not success:
        return {"message": "Game not found"}
    
    game = active_games[game_id]
    session = game.currentSession
    
    turn_order = [{"name": p.name, "id": p.id} for p in session.playOrder]
    first_player = session.playOrder[0]
    
    for player in game.loPlayers:
        if player == session.currentImpostor:
            await manager.send_to_player(game_id, player.id, {
                "type": "session_started",
                "data": {
                    "role": "impostor",
                    "word": None,
                    "turn_order": turn_order,
                    "current_turn": first_player.name,
                    "current_turn_id": first_player.id,
                    "clue_timer": game.clueTimer,
                    "max_round": game.maxRound
                }
            })
        else:
            await manager.send_to_player(game_id, player.id, {
                "type": "session_started",
                "data": {
                    "role": "player",
                    "word": session.secretWord,
                    "turn_order": turn_order,
                    "current_turn": first_player.name,
                    "current_turn_id": first_player.id,
                    "clue_timer": game.clueTimer,
                    "max_round": game.maxRound
                }
            })
    
    game.nextPhase()  # LOBBY → DELEGATION
    return {"message": "Successfully started the session"}

@app.get("/game/{game_id}/state")
def get_game_state(game_id:str):
    game = active_games[game_id]
    players = [{"id": p.id, "name": p.name, "points": p.points} for p in game.loPlayers]
    
    session_info = None
    if game.currentSession:
        session_info = {
            "secret_word": game.currentSession.secretWord,
            "impostor_id": game.currentSession.currentImpostor.id}
    
    return {
        "current_phase": game.phase.value,
        "players_list": players,
        "current_session": session_info}

@app.post("/game/vote")
def vote_endpoint(game_id: str, player_id: str, vote_for_id: str):
    success = submit_vote(game_id, player_id, vote_for_id)
    if success:
        return {"message": "Vote submitted"}
    else:
        return {"message": "Vote failed"}

@app.post("/game/end_session")
def end_session_endpoint(game_id: str):
    result = end_session(game_id)
    if result:
        return result
    else:
        return {"message": "Game not found"}
    
@app.websocket("/ws/{game_id}/{player_id}")

async def websocket_endpoint(websocket: WebSocket, game_id: str, player_id: str):
    await manager.connect(websocket, game_id, player_id)
    
    try:
        while True:
            message = await websocket.receive_json()
            await handle_message(game_id, player_id, message)
            #This keeps this loop running, but await lets other code run
            
    except WebSocketDisconnect:
        manager.disconnect(game_id, player_id)
        await manager.broadcast_to_game(game_id, {
            "type": "player_disconnected",
            "player_id": player_id
        })

async def handle_message(game_id: str, player_id: str, message: dict):
    update_activity(game_id)
    message_type = message.get("type")
    data = message.get("data", {})
    
    if message_type == "end_turn":
        await handle_end_turn(game_id, player_id)
    
    elif message_type == "submit_vote":
        vote_for_id = data.get("vote_for_id")
        await handle_vote(game_id, player_id, vote_for_id)
    
    elif message_type == "start_next_session":
        await handle_start_next_session(game_id, player_id)
    
    elif message_type == "toggle_ready":
        await handle_toggle_ready(game_id, player_id)
    
    elif message_type == "toggle_ready_start":
        await handle_toggle_ready_start(game_id, player_id)
    
    elif message_type == "finalize_votes":
        await handle_finalize_votes(game_id, player_id)
    
    elif message_type == "new_game":
        new_category = data.get("category")
        max_round = data.get("max_round")
        clue_timer = data.get("clue_timer")
        passcode = data.get("passcode", "")
        await handle_new_game(game_id, player_id, new_category, max_round, clue_timer, passcode)
    
    elif message_type == "quit_game":
        await handle_quit_game(game_id, player_id)
    
    elif message_type == "skip_turn":
        await handle_skip_turn(game_id, player_id)

    elif message_type == "change_timer":
        new_time = data.get("new_time", 30)
        await handle_change_timer(game_id, player_id, new_time)
    
    elif message_type == "continue_game":
        await handle_continue_game(game_id, player_id)

async def handle_end_turn(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game or not game.currentSession:
        return
    
    session = game.currentSession
    
    # Move to next turn
    session.currentTurnIndex += 1
    
    # Reset to 0 if we've gone through everyone
    if session.currentTurnIndex >= len(session.playOrder):
        session.currentTurnIndex = 0
    
    # Get next player
    next_player = session.playOrder[session.currentTurnIndex]
    
    await manager.broadcast_to_game(game_id, {
        "type": "next_turn",
        "data": {
            "player_id": next_player.id,
            "player_name": next_player.name
        }
    })

async def handle_toggle_ready(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game:
        return
    
    # Find the player and toggle their status
    player = None
    for p in game.loPlayers:
        if p.id == player_id:
            p.toggle_ready_to_vote()
            player = p
            break
    
    if not player:
        return
    
    # Count how many are ready
    ready_count = sum(1 for p in game.loPlayers if p.ready_to_vote)
    total_players = len(game.loPlayers)
    
    # Broadcast the change
    await manager.broadcast_to_game(game_id, {
        "type": "player_ready_changed",
        "data": {
            "player_id": player_id,
            "is_ready": player.ready_to_vote,
            "ready_count": ready_count,
            "total_players": total_players
        }
    })
    
    # Check if everyone is ready
    if ready_count == total_players:
        game.nextPhase()  # Transition to VOTING
        await manager.broadcast_to_game(game_id, {
            "type": "clue_phase_complete",
            "data": {}
        })

async def handle_vote(game_id: str, player_id: str, vote_for_id: str):
    game = active_games.get(game_id)
    if not game:
        return
    
    # Find the voting player
    voting_player = None
    for p in game.loPlayers:
        if p.id == player_id:
            voting_player = p
            break
    
    if not voting_player:
        return
    
    # If player already voted for someone, remove that vote first
    if voting_player.voted_for_id:
        for p in game.loPlayers:
            if p.id == voting_player.voted_for_id:
                p.votes -= 1
                break
    
    # Add new vote
    for p in game.loPlayers:
        if p.id == vote_for_id:
            p.votes += 1
            break
    
    # Update who this player voted for
    voting_player.voted_for_id = vote_for_id
    voting_player.has_voted = True
    
    # Count how many have voted
    votes_in = sum(1 for p in game.loPlayers if p.has_voted)
    total_players = len(game.loPlayers)
    
    # Build vote tally for broadcast
    vote_tally = [
        {"id": p.id, "name": p.name, "votes": p.votes} 
        for p in game.loPlayers
    ]
    
    await manager.broadcast_to_game(game_id, {
        "type": "vote_update",
        "data": {
            "voter_id": player_id,
            "voted_for_id": vote_for_id,
            "votes_in": votes_in,
            "total_players": total_players,
            "vote_tally": vote_tally
        }
    })

async def handle_finalize_votes(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game:
        return
    
    # Only host can finalize
    if player_id != game.hostID:
        return
    
    # Check for tie - find top vote count
    max_votes = 0
    for p in game.loPlayers:
        if p.votes > max_votes:
            max_votes = p.votes
    
    # Count how many players have the max votes
    players_with_max = sum(1 for p in game.loPlayers if p.votes == max_votes)
    
    # If tie (more than one player with max votes), don't allow finalize
    if players_with_max > 1:
        await manager.broadcast_to_game(game_id, {
            "type": "vote_tie",
            "data": {
                "message": "It's a tie! Keep voting until there's a majority."
            }
        })
        return
    
    # End session and get results
    result = end_session(game_id)
    
    # Check if game is over (no more rounds)
    rounds_remaining = len(game.impostorSchedule)
    
    await manager.broadcast_to_game(game_id, {
        "type": "session_results",
        "data": {
            "impostor_caught": result["impostor_caught"],
            "impostor_name": result["impostor_name"],
            "voted_out_name": result["voted_out_name"],
            "players": [{"name": p.name, "points": p.points} for p in game.loPlayers],
            "game_over": rounds_remaining == 0
        }
    })
    
    # Reset vote state for next session
    for p in game.loPlayers:
        p.has_voted = False
        p.voted_for_id = None
        p.votes = 0

async def handle_start_next_session(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game:
        return
    
    # Only host can start next session
    if player_id != game.hostID:
        return
    
    # Start the session (creates new SecretWordSession)
    success = start_session(game_id)
    if not success:
        return
    
    session = game.currentSession
    
    # Build turn order info (list of player names)
    turn_order = [{"name": p.name, "id": p.id} for p in session.playOrder]
    first_player = session.playOrder[0]
    
    # Send personalized message to each player
    for player in game.loPlayers:
        if player == session.currentImpostor:
            # Impostor gets no word
            await manager.send_to_player(game_id, player.id, {
                "type": "session_started",
                "data": {
                    "role": "impostor",
                    "word": None,
                    "turn_order": turn_order,
                    "current_turn": first_player.name,
                    "current_turn_id": first_player.id,
                    "clue_timer": game.clueTimer,
                    "max_round": game.maxRound
                }
            })
        else:
            # Regular players get the word
            await manager.send_to_player(game_id, player.id, {
                "type": "session_started",
                "data": {
                    "role": "player",
                    "word": session.secretWord,
                    "turn_order": turn_order,
                    "current_turn": first_player.name,
                    "current_turn_id": first_player.id,
                    "clue_timer": game.clueTimer,
                    "max_round": game.maxRound
                }
            })

    # Reset ready flags for all players
    for p in game.loPlayers:
        p.ready_to_vote = False
        p.ready_to_start = False
    
    # Update game phase
    game.nextPhase()  # LOBBY → DELEGATION

async def handle_toggle_ready_start(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game:
        return
    
    # Find player and toggle
    player = None
    for p in game.loPlayers:
        if p.id == player_id:
            p.toggle_ready_to_start()
            player = p
            break
    
    if not player:
        return
    
    # Count ready players
    ready_count = sum(1 for p in game.loPlayers if p.ready_to_start)
    total_players = len(game.loPlayers)
    
    # Broadcast update
    await manager.broadcast_to_game(game_id, {
        "type": "player_ready_start_changed",
        "data": {
            "player_id": player_id,
            "is_ready": player.ready_to_start,
            "ready_count": ready_count,
            "total_players": total_players
        }
    })
    
    # Check if everyone ready
    if ready_count == total_players:
        # Transition to clue phase
        game.nextPhase()  # DELEGATION → DECEPTION
        
        session = game.currentSession
        first_player = session.playOrder[0]
        
        await manager.broadcast_to_game(game_id, {
            "type": "clue_phase_started",
            "data": {
                "current_turn": first_player.name,
                "current_turn_id": first_player.id,
                "clue_timer": game.clueTimer  # Could be 0 for no timer
            }
        })
        
        # Reset ready flags for next time
        for p in game.loPlayers:
            p.ready_to_start = False
    
async def handle_new_game(game_id: str, player_id: str, new_category: str = None, max_round: int = None, clue_timer: int = None, passcode: str = ""):
    game = active_games.get(game_id)
    if not game:
        return
    
    # Only host can start new game
    if player_id != game.hostID:
        return
    
    # Update category if provided (requires passcode)
    if new_category:
        if passcode != os.environ.get("CATEGORY_PASSCODE", ""):
            return
        game.secretCategory = new_category
        game.wordsUsed = []
    
    # Update rounds if provided
    if max_round:
        game.maxRound = max_round

    # Update timer if provided (0 is valid for no-timer mode)
    if clue_timer is not None:
        game.clueTimer = clue_timer
    
    # Reset game state
    game.wordsAvailable = []
    game.impostorSchedule = []
    
    # Reset player points
    for p in game.loPlayers:
        p.points = 0
        p.ready_to_start = False
        p.ready_to_vote = False
        p.has_voted = False
        p.voted_for_id = None
        p.votes = 0
    
    # Regenerate words and impostor schedule
    from game_manager import createImpostorSchedule
    from claude_service import generate_secret_word
    
    game.impostorSchedule = createImpostorSchedule(game.loPlayers, game.maxRound)
    words = generate_secret_word(game.secretCategory, game.maxRound, game.wordsUsed)
    game.fillAvailableWords(words)
    
    # Reset phase
    game.phase = GamePhase.LOBBY
    
    await manager.broadcast_to_game(game_id, {
        "type": "new_game_started",
        "data": {
            "category": game.secretCategory,
            "same_category": new_category is None
        }
    })

async def handle_quit_game(game_id: str, player_id: str):
    result = quit_game(game_id, player_id)
    
    if result["status"] == "game_deleted":
        await manager.broadcast_to_game(game_id, {
            "type": "game_deleted",
            "data": {}
        })
        return
    
    if result["status"] == "player_removed":
        # Notify remaining players
        await manager.broadcast_to_game(game_id, {
            "type": "player_quit",
            "data": {
                "player_name": result["player_name"],
                "player_id": player_id,
                "new_host_id": result["new_host_id"]
            }
        })
    
    # Disconnect the quitting player's websocket
    manager.disconnect(game_id, player_id)

async def handle_continue_game(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game:
        return
    if player_id != game.hostID:
        return
    
    await manager.broadcast_to_game(game_id, {
        "type": "host_choosing_settings",
        "data": {}
    })

async def handle_skip_turn(game_id: str, player_id: str):
    game = active_games.get(game_id)
    if not game or not game.currentSession:
        return
    
    # Only host can skip
    if player_id != game.hostID:
        return
    
    session = game.currentSession
    
    # Move to next turn
    session.currentTurnIndex += 1
    if session.currentTurnIndex >= len(session.playOrder):
        session.currentTurnIndex = 0
    
    next_player = session.playOrder[session.currentTurnIndex]
    
    await manager.broadcast_to_game(game_id, {
        "type": "next_turn",
        "data": {
            "player_id": next_player.id,
            "player_name": next_player.name,
            "was_skipped": True
        }
    })

async def handle_change_timer(game_id: str, player_id: str, new_time: int):
    game = active_games.get(game_id)
    if not game:
        return
    if player_id != game.hostID:
        return
    
    game.clueTimer = new_time
    
    await manager.broadcast_to_game(game_id, {
        "type": "timer_changed",
        "data": {"new_time": new_time}
    })

