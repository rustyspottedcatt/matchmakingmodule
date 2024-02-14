--[=[
    This script demonstrates the instantiation of the MultiplayerSessionManager and shows
    how to connect to and handle events for managing multiplayer sessions in a Roblox game.
    It includes session creation, players joining and leaving, and the session's lifecycle.
]=]

-- Assuming MultiplayerSessionManager is a module located in 'ReplicatedStorage.Packages.MultiplayerSessionManager'
local MultiplayerSessionManagerModule = require(game.ReplicatedStorage.Packages.MultiplayerSessionManager)
local sessionManager = MultiplayerSessionManagerModule.new() -- Proper instantiation using .new()

--[=[
    Set up event handlers for session-related events on the instantiated sessionManager.
    This includes handling session creation, player joining, player leaving, and session
    ending events with actions defined for when these events are triggered.
]=]
local function setupSessionEventHandlers(sessionManager)
	sessionManager.OnSessionCreated:Connect(function(session)
		print("Session Created:", session.sessionID)
	end)

	sessionManager.OnPlayerJoinedSession:Connect(function(session, player)
		print(string.format("Player %s joined the session %s", player.Name, session.sessionID))
	end)

	sessionManager.OnPlayerLeftSession:Connect(function(session, player)
		print(string.format("Player %s left the session %s", player.Name, session.sessionID))
	end)

	sessionManager.OnSessionEnded:Connect(function(session)
		print("Session Ended:", session.sessionID)
	end)
end

--[=[
    Creates a mock player object. In actual usage, Roblox's Player objects would be utilized.
]=]
local function createMockPlayer(name)
	return {
        [name] = {
            Name = name,
            IsA = function(self, className) return true end, -- Mock function for demonstration
            playerID = name -- Simplified identification
        }
    }
end

--[=[
    Demonstrate session management using the instantiated sessionManager, including
    creating a session, adding and removing players, and concluding the session,
    with event handlers monitoring these actions.
]=]
local function demonstrateSessionManagement(sessionManager)

	-- Define session parameters
	local sessionID = "SessionDemo"
	local mockPlayers = {createMockPlayer("Alice")} -- Initial set of players
	local sessionMaxCapacity = 3
	local sessionLife = 1800 -- 30 minutes in seconds
	local sessionData = {map = "Castle", mode = "Hide and Seek"}
	local matchmakingPreferences = {
		preferredRegion = "Europe",
		gameMode = "Fun",
		skillLevel = 1
	}

	-- Create the session
	sessionManager:createSession(sessionID, mockPlayers, sessionMaxCapacity, sessionLife, sessionData, matchmakingPreferences)

	-- Simulate player interactions
	local newPlayer = createMockPlayer("Bob")
	sessionManager:joinSession(newPlayer, sessionID)

	local anotherPlayer = createMockPlayer("Charlie")
	sessionManager:joinSession(anotherPlayer, sessionID)

	-- Check the current state of session players
	for _, player in ipairs(sessionManager.__RegisteredSessions[sessionID].sessionPlayers) do
		warn("- Player:", player.Name)
	end

	-- Simulate a player leaving
	sessionManager:leaveSession(newPlayer, sessionID)
    sessionManager:leaveSession(anotherPlayer, sessionID)

	-- Check the current state of session players after one leaves
	for _, player in ipairs(sessionManager.__RegisteredSessions[sessionID].sessionPlayers) do
		warn("- Player:", player.Name)
	end

	-- End the session
	task.wait(5)
	sessionManager:endSession(sessionID)
end


-- Initialize event handlers and run the demonstration with the instantiated sessionManager
setupSessionEventHandlers(sessionManager)
demonstrateSessionManagement(sessionManager)
