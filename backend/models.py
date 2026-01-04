from enum import Enum
import random
from math import floor

class GamePhase (Enum):
    #this class is to help keep track of which phase of the game its in
    LOBBY = "lobby"
    DELEGATION = "delegation"
    DECEPTION = "deception"
    VOTING = "voting"
    RESULTS = "results"

class Player ():
    #class for each human player that will be playing
    def __init__(self, name, id):
        self.id = id
        self.name = name
        self.imposter = False
        #reset every SWS
        self.votes = 0
        #reset every SWS
        self.ready_to_start = False
            
        self.ready_to_vote = False
        #reset after ever sws
        self.points = 0
        self.has_voted = False
        self.voted_for_id = None

    def toggle_ready_to_start(self):
        self.ready_to_start = not self.ready_to_start

    def toggle_ready_to_vote (self):
        self.ready_to_vote  = not self.ready_to_vote

class SecretWordSession ():
    def __init__(self, ListOfPlayers: list[Player], secretWord:str, currentImpostor:Player):
        self.playOrder = ListOfPlayers.copy()
        random.shuffle(self.playOrder)
        self.secretWord = secretWord
        self.currentTurnIndex = 0
        self.currentImpostor = currentImpostor
    
class GamePlay ():
    def __init__(self, gameID, hostID, maxRound, clueTimer,secretCategory):
        self.gameID = gameID
        self.hostID = hostID
        self.maxRound = maxRound
        self.clueTimer = clueTimer
        self.secretCategory:str = secretCategory
        self.roundTimer = 0
        self.phase = GamePhase.LOBBY
        self.loPlayers : list[Player] = []
        self.impostorSchedule: list[Player] = []
        self.wordsAvailable = []
        self.wordsUsed = []
        self.currentSession :SecretWordSession = None
        
    
    def changeCategory (self, descriptionNew: str):
        self.secretCategory = descriptionNew
    
    def changeClueTimer (self, clueTimeNew):
        self.clueTimer = clueTimeNew

    def addNewPlayer (self, playerNew : Player):
        self.loPlayers.append(playerNew)
    
    def removePlayer(self, playerRemove):
        self.loPlayers.remove(playerRemove)

    def nextPhase(self):
        match self.phase:
            case GamePhase.LOBBY:
                self.phase = GamePhase.DELEGATION
            case GamePhase.DELEGATION:
                self.phase = GamePhase.DECEPTION
            case GamePhase.DECEPTION:
                self.phase = GamePhase.VOTING
            case GamePhase.VOTING:
                self.phase = GamePhase.RESULTS
            case GamePhase.RESULTS:
                self.phase = GamePhase.LOBBY
            case _:
                print("Error Switching Game Phase")
    
    def prevPhase(self):
        match self.phase:
            case GamePhase.LOBBY:
                self.phase = GamePhase.RESULTS
            case GamePhase.DELEGATION:
                self.phase = GamePhase.LOBBY
            case GamePhase.DECEPTION:
                self.phase = GamePhase.DELEGATION
            case GamePhase.VOTING:
                self.phase = GamePhase.DECEPTION
            case GamePhase.RESULTS:
                self.phase = GamePhase.VOTING
            case _:
                print("Error Switching Game Phase")
    
    def fillAvailableWords(self, words:list[str]) -> None:
        self.wordsAvailable.extend(words)

    def giveWord (self):
        currWord = random.choice(self.wordsAvailable)
        self.wordsAvailable.remove(currWord)
        self.wordsUsed.append(currWord)
        return currWord

    def updateUsedWords(self, usedWords):
        self.wordsUsed.extend(usedWords)

