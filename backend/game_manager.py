from models import GamePlay, Player, SecretWordSession
from claude_service import generate_secret_word 
import random
import string
import json
import os
from datetime import datetime


active_games = {}
active_players = {}

def create_game(host_id, max_round, clue_timer, secret_category):
    game_id = generate_game_id()
    game = GamePlay(game_id, host_id, max_round, clue_timer, secret_category)
    
    # Auto-add host to the game
    host = active_players.get(host_id)
    if host:
        game.addNewPlayer(host)
    
    active_games[game_id] = game
    return game_id

def register_player(name : str) -> str:
     player_id = generate_player_id()
     player = Player(name, player_id)
     active_players[player_id] = player
     return player_id

def generate_game_id() -> str:
    # Exclude ambiguous characters: 0, O, 1, I, L
    safe_chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    while True:
        game_id = ''.join(random.choices(safe_chars, k=6))
        if game_id not in active_games:
            return game_id

def generate_player_id():
    # Exclude ambiguous characters: 0, O, 1, I, L
    safe_chars = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    while True:
        player_id = ''.join(random.choices(safe_chars, k=6))
        if player_id not in active_players:
            return player_id

def join_game(player_id : str, game_id:str):
    try:
        game = active_games[game_id] 
    except KeyError:
         print(f"The game was not found. Please confirm you have the correct game id: {game_id}, and try again")
         return False
    player = active_players[player_id]
    
    # Prevent duplicate joins
    for p in game.loPlayers:
        if p.id == player_id:
            return True  # Already in the game, just return success
    
    game.addNewPlayer(player)
    print(f"Player {player_id} joined game {game_id}")
    return True

def start_game(game_id: str) -> bool:
    try:
        currentgame = active_games[game_id]
        currentgame.impostorSchedule = createImpostorSchedule(currentgame.loPlayers, currentgame.maxRound)
        
        if currentgame.secretCategory:
            words = generate_secret_word(currentgame.secretCategory, currentgame.maxRound, currentgame.wordsUsed)
        else:
            words = load_default_words(currentgame.maxRound, currentgame.wordsUsed)
        
        currentgame.fillAvailableWords(words)
        return True
    except KeyError:
        return False
    
def start_session(game_id):
    try:
        current_game = active_games[game_id]
        if not current_game.wordsAvailable:
            if current_game.secretCategory:
                current_game.wordsAvailable = generate_secret_word(current_game.secretCategory, current_game.maxRound, current_game.wordsUsed)
            else:
                current_game.wordsAvailable = load_default_words(current_game.maxRound, current_game.wordsUsed)
        impostor = current_game.impostorSchedule.pop(0)
        currentWord = current_game.giveWord()
        session = SecretWordSession(current_game.loPlayers, currentWord, impostor)
        current_game.currentSession = session
        return True
    except KeyError:
        return False

def createImpostorSchedule(players, maxRounds):
        totalPlayers = len(players)
        lofImposters = players.copy()
        extras = int(maxRounds) - totalPlayers
        if extras > totalPlayers:
            playersToAdd = random.choices(players, k=extras)
            lofImposters.extend(playersToAdd)
            random.shuffle(lofImposters)
            return lofImposters

        elif totalPlayers < maxRounds:
            #this code is ensure everyone has a chance to play, but its not predictable, so some people are added twice 
            playersToAdd = random.sample(players,extras)
            lofImposters.extend(playersToAdd)
            random.shuffle(lofImposters)
            return lofImposters

        else:
            return random.sample(lofImposters,maxRounds)

def submit_vote(game_id: str, player_id: str, vote_for_id: str) -> bool:
    try:
        game = active_games[game_id]
        # Find the player being voted for and increment their votes
        for player in game.loPlayers:
            if player.id == vote_for_id:
                player.votes += 1
                return True
        return False  # Player not found
    except KeyError:
        return False

def end_session(game_id: str) -> dict:
    try:
        game = active_games[game_id]
        session = game.currentSession
        
        # Find player with most votes
        most_votes = 0
        voted_out = None
        for player in game.loPlayers:
            if player.votes > most_votes:
                most_votes = player.votes
                voted_out = player
        
        # Check if impostor was caught
        impostor = session.currentImpostor
        impostor_caught = (voted_out == impostor)
        
        # Award points
        if impostor_caught:
            # Everyone except impostor gets a point
            for player in game.loPlayers:
                if player != impostor:
                    player.points += 1
        else:
            # Impostor gets a point
            impostor.points += 1
        
        # Reset votes for next session
        for player in game.loPlayers:
            player.votes = 0
        
        return {
            "impostor_caught": impostor_caught,
            "impostor_name": impostor.name,
            "voted_out_name": voted_out.name if voted_out else None
        }
    except KeyError:
        return None

def load_default_words(count: int, used_words: list[str]) -> list[str]:
    words_path = os.path.join(os.path.dirname(__file__), "words.json")
    with open(words_path, "r") as f:
        word_data = json.load(f)
    
    # Flatten all categories into one list
    all_words = []
    for category_words in word_data.values():
        all_words.extend(category_words)
    
    # Remove any already used words
    available = [w for w in all_words if w not in used_words]
    
    return random.sample(available, min(count, len(available)))

def quit_game(game_id: str, player_id: str) -> dict:
    game = active_games.get(game_id)
    if not game:
        return {"status": "game_not_found"}
    
    # Remove player from game
    player_to_remove = None
    for p in game.loPlayers:
        if p.id == player_id:
            player_to_remove = p
            break
    
    if not player_to_remove:
        return {"status": "player_not_found"}
    
    game.loPlayers.remove(player_to_remove)
    
    # Remove from active players
    if player_id in active_players:
        del active_players[player_id]
    
    # Remove from impostor schedule if present
    game.impostorSchedule = [p for p in game.impostorSchedule if p.id != player_id]
    
    # If no players left, delete the game
    if not game.loPlayers:
        del active_games[game_id]
        return {"status": "game_deleted"}
    
    # If host quit, transfer to next player
    new_host_id = None
    if player_id == game.hostID:
        new_host = game.loPlayers[0]
        game.hostID = new_host.id
        new_host_id = new_host.id
    
    return {
        "status": "player_removed",
        "new_host_id": new_host_id,
        "player_name": player_to_remove.name
    }

def cleanup_inactive_games(timeout_minutes: int = 5) -> list[str]:
    now = datetime.now()
    games_to_delete = []
    
    for game_id, game in list(active_games.items()):
        minutes_inactive = (now - game.last_activity).total_seconds() / 60
        if minutes_inactive >= timeout_minutes:
            # Remove all players from active_players
            for player in game.loPlayers:
                if player.id in active_players:
                    del active_players[player.id]
            del active_games[game_id]
            games_to_delete.append(game_id)
    
    return games_to_delete

def update_activity(game_id: str):
    game = active_games.get(game_id)
    if game:
        game.last_activity = datetime.now()

def rejoin_game(game_id: str, player_id: str) -> dict:
    game = active_games.get(game_id)
    if not game:
        return {"status": "game_not_found"}
    
    # Check if player is still in the game
    player = None
    for p in game.loPlayers:
        if p.id == player_id:
            player = p
            break
    
    if not player:
        return {"status": "player_not_found"}
    
    # Build current game state
    players = [{"id": p.id, "name": p.name, "points": p.points} for p in game.loPlayers]
    
    session_data = None
    if game.currentSession:
        session = game.currentSession
        is_impostor = (player == session.currentImpostor)
        turn_order = [{"name": p.name, "id": p.id} for p in session.playOrder]
        current_turn = session.playOrder[session.currentTurnIndex]
        
        session_data = {
            "role": "impostor" if is_impostor else "player",
            "word": None if is_impostor else session.secretWord,
            "turn_order": turn_order,
            "current_turn": current_turn.name,
            "current_turn_id": current_turn.id,
            "clue_timer": game.clueTimer,
        }
    
    return {
        "status": "success",
        "phase": game.phase.value,
        "players": players,
        "is_host": player_id == game.hostID,
        "session": session_data,
    }