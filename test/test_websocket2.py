import asyncio
import websockets
import json

async def test_connection():
    # Replace with your actual game_id and player_id from testing above
    game_id = "N5C45Y"
    player_id = "9KPKHG"
    
    uri = f"ws://127.0.0.1:8000/ws/{game_id}/{player_id}"
    
    async with websockets.connect(uri) as websocket:
        print(f"Connected to {uri}")
        
        # Listen for messages
        while True:
            try:
                message = await websocket.recv()
                print(f"Received: {message}")
            except websockets.exceptions.ConnectionClosed:
                print("Connection closed")
                break

asyncio.run(test_connection())