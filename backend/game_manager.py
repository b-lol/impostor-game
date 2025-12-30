from models import GamePlay, Player
import random
import string

active_games = {}

def create_game(host_id, max_round, clue_timer, secret_category):
    game_id = generate_game_id()
    
    game = GamePlay(game_id, host_id, max_round, clue_timer, secret_category)
    
    active_games[game_id] = game
    
    return game_id

def generate_game_id()-> str:
    while True:
        game_id = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        if game_id not in active_games:
            return game_id
