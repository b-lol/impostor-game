from fastapi import FastAPI
from game_manager import register_player, create_game,join_game, start_game, start_session, active_games, submit_vote, end_session


app = FastAPI()

@app.post("/player/register")
def register_player_endpoint(name:str):
    player_id = register_player(name)
    return {"player_id": player_id}

@app.post("/game/create")
def create_game_endpoint(host_id, max_round, clue_time, secret_category):
    game_id = create_game(host_id, max_round, clue_time, secret_category)
    return {"game_id": game_id}

@app.post("/game/join")
def join_game_endpoint(player_id, game_id):
    success = join_game(player_id, game_id)
    if success:
        return{"message":"Successfully joined the game"}
    else: return {"message":"Game not found"}

@app.post("/game/start")
def start_game_endpoint(game_id):
    success = start_game(game_id)
    if success:
        return{"message":"Successfully started the game"}
    else: return {"message":"Game not found"}

@app.post("/session/start")
def session_start_endpoint(game_id):
    success = start_session(game_id)
    if success:
        return{"message":"Successfully started the session"}
    else: return {"message":"Game not found"}

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