from models import GamePlay, Player, SecretWordSession
from claude_service import generate_secret_word 
import random
import string
import json
import os


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
