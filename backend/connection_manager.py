class ConnectionManager:
    def __init__(self):
        self.active_connections={}

    async def connect(self, websocket, game_id: str, player_id: str):
        await websocket.accept()
        
        if game_id not in self.active_connections:
            self.active_connections[game_id] = {}
        
        self.active_connections[game_id][player_id] = websocket


    def disconnect(self, game_id: str, player_id: str):
        if game_id in self.active_connections:
            if player_id in self.active_connections[game_id]:
                del self.active_connections[game_id][player_id]
            
            # Clean up empty games
            if not self.active_connections[game_id]:
                del self.active_connections[game_id]

    async def broadcast_to_game(self, game_id: str, message: dict):
        if game_id in self.active_connections:
            for websocket in self.active_connections[game_id].values():
                await websocket.send_json(message)

    async def send_to_player(self, game_id: str, player_id: str, message: dict):
            if game_id in self.active_connections:
                if player_id in self.active_connections[game_id]:
                    websocket = self.active_connections[game_id][player_id]
                    await websocket.send_json(message)

