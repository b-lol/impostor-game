from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from game_manager import register_player, create_game,join_game, start_game, start_session, active_games, submit_vote, end_session
from connection_manager import ConnectionManager


app = FastAPI()
manager = ConnectionManager()

@app.post("/player/register")
def register_player_endpoint(name:str):
    player_id = register_player(name)
    return {"player_id": player_id}

@app.post("/game/create")
def create_game_endpoint(host_id: str, max_round: int, clue_time: int, secret_category: str):
    game_id = create_game(host_id, max_round, clue_time, secret_category)
    return {"game_id": game_id}

@app.post("/game/join")
def join_game_endpoint(player_id: str, game_id: str):
    success = join_game(player_id, game_id)
    if success:
        return{"message":"Successfully joined the game"}
    else: return {"message":"Game not found"}

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
    
    turn_order = [p.name for p in session.playOrder]
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
                    "clue_timer": game.clueTimer
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
                    "clue_timer": game.clueTimer
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
    
    success = submit_vote(game_id, player_id, vote_for_id)
    
    if success:
        # Count votes submitted
        votes_in = sum(1 for p in game.loPlayers if p.votes > 0)
        # This isn't quite right - we need to track WHO has voted, not vote counts
        # But let's keep it simple for now
        
        await manager.broadcast_to_game(game_id, {
            "type": "vote_received",
            "data": {
                "player_id": player_id,
                "total_players": len(game.loPlayers)
            }
        })

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
    turn_order = [p.name for p in session.playOrder]
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
                    "current_turn_id": first_player.id
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
                    "current_turn_id": first_player.id
                }
            })
    
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