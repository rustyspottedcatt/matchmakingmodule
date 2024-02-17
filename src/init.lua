--[[
    https://www.roblox.com/users/1539582829/profile
    https://twitter.com/zzen_a

    MIT License

    Copyright (c) 2023 rustyspotted

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

--[[
    MultiplayerSessionManager Module
    Description:
        This module manages multiplayer sessions for Roblox games, providing functionalities
        to create, update, join, leave, and monitor changes in game sessions. It's designed
        to enhance multiplayer experiences by allowing developers to manage game sessions
        dynamically, including support for session matchmaking, player tracking, and session
        property change notifications.
]]

local RunService = game:GetService("RunService")

local MultiplayerSessionManager = {}
MultiplayerSessionManager.__index = MultiplayerSessionManager
MultiplayerSessionManager.__RegisteredSessions = {}
MultiplayerSessionManager.__ArchivedSessions = {}
MultiplayerSessionManager.__RecordedSessions = {}
MultiplayerSessionManager.Presets = (script.Parent :: Instance)

local Promise = require(MultiplayerSessionManager.Presets.promise)
local Signal = require(MultiplayerSessionManager.Presets.signal)

local isServer = RunService:IsServer()

export type MatchmakingPreferences = {
    preferredRegion: string?,
    gameMode: string, 
    skillLevel: number?, 
}

export type Session = {
    sessionID: string, 
    sessionPlayers: {Player | table},
    sessionMaxCapacity: number,
    sessionStartTime: number,
    sessionEndTime: number?,
    sessionLife : number,
    sessionData: table?,
}

export type Connection = {
    Disconnect: () -> nil?,
}

export type Signal<T> = {
    Connect: (listener: (T) -> nil?) -> Connection,
    Fire: (data: T) -> nil?,
}

local function deepcopy(orig)
    assert(orig, "Original table was not defined")

    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

local function onChange(sessionID, key, newValue, oldValue)
    assert(sessionID, "SessionID not defined")
    assert(newValue, "newValue not defined")
    assert(key, "key not defined")
    assert(oldValue, "oldValue not defined")
    
    print(string.format("Session %s: %s changed from %s to %s", sessionID, key, tostring(oldValue), tostring(newValue)))
end

function MultiplayerSessionManager.new()
    local self = setmetatable({}, MultiplayerSessionManager)

    self.__RegisteredSessions = {}
    self.OnSessionCreated = Signal.new()
    self.OnPlayerJoinedSession = Signal.new()
    self.OnPlayerLeftSession = Signal.new()
    self.OnSessionEnded = Signal.new()

    return self
end

function MultiplayerSessionManager:createSession(sessionID : string, sessionPlayers : {Player}?, sessionMaxCapacity : number, sessionLife : number, sessionData : table, matchmakingPreferences : MatchmakingPreferences?) : Session | nil
    assert(sessionID, string.format("Invalid argument, got `%s` expected `%s`.", typeof(sessionID) or "nil", "string"))
    assert(sessionPlayers, string.format("Invalid argument, got `%s` expected `%s`.", typeof(sessionPlayers) or "nil", "{ Player }"))
    assert(sessionMaxCapacity, string.format("Invalid argument, got `%s` expected `%s`.", typeof(sessionMaxCapacity) or "nil", "number"))
    assert(sessionLife, string.format("Invalid argument, got `%s` expected `%s`.", typeof(sessionLife) or "nil", "string"))
    assert(sessionData, string.format("Invalid argument, got `%s` expected `%s`.", typeof(sessionData) or "nil", "table"))
    assert(matchmakingPreferences, string.format("Invalid argument, got `%s` expected `%s`.", typeof(matchmakingPreferences) or "nil", "table"))
    assert(not self.__RegisteredSessions[sessionID], "SessionID was already registered")
    assert(isServer, string.format("Function `%s` can only be called on the server side", ":createSession()"))

    self.__RegisteredSessions[sessionID] = {
        sessionID = sessionID,
        sessionPlayers = sessionPlayers or {},
        sessionMaxCapacity = sessionMaxCapacity,
        sessionStartTime = os.time(),
        sessionEndTime = nil,
        sessionLife = sessionLife,
        sessionData = sessionData or {},
        matchmakingPreferences = matchmakingPreferences,
    }
    self.OnSessionCreated:Fire(self.__RegisteredSessions[sessionID])

    return self.__RegisteredSessions[sessionID] or nil
end

function MultiplayerSessionManager:joinSession(playerOrPlayers : {Player | table}, sessionID : string)
    assert(self.__RegisteredSessions[sessionID], "Couldn't find session")
    assert(isServer, string.format("Function `%s` can only be called on the server side", ":joinSession()"))

	local session = self.__RegisteredSessions[sessionID]
	if not session or #session.sessionPlayers >= session.sessionMaxCapacity then
		warn("Session is full or does not exist")
		return
	end
	
	local players = (type(playerOrPlayers) == "table") and playerOrPlayers or {playerOrPlayers}
	for _, player in pairs(players) do
		if not player:IsA("Player") then
			warn("Attempted to add a non-player object to the session")
			return
		end

		if #session.sessionPlayers < session.sessionMaxCapacity then
			table.insert(session.sessionPlayers, player)
			self.OnPlayerJoinedSession:Fire(session, player)
		else
			warn("Session is full")
			break
		end
	end
end

function MultiplayerSessionManager:leaveSession(playerOrPlayers : {Player | table}, sessionID)
    assert(self.__RegisteredSessions[sessionID], "Couldn't find session")
    assert(isServer, string.format("Function `%s` can only be called on the server side", ":leaveSession()"))

	local session = self.__RegisteredSessions[sessionID]
	if not session then
		warn("Session does not exist")
		return
	end
	
	local players = (type(playerOrPlayers) == "table") and playerOrPlayers or {playerOrPlayers}

	for _, player in pairs(players) do
		for i = #session.sessionPlayers, 1, -1 do
			if session.sessionPlayers[i] == player then
				table.remove(session.sessionPlayers, i)
				self.OnPlayerLeftSession:Fire(session, player)
				break
			end
		end

		if #session.sessionPlayers == 0 then
			self:endSession(sessionID)
		end
	end
end

function MultiplayerSessionManager:endSession(sessionID)
    assert(self.__RegisteredSessions[sessionID], "Couldn't find session")

    Promise.new(function(resolve, reject)
        local session = self.__RegisteredSessions[sessionID]
        if session then
            resolve(session)
        else
            reject()
        end
    end):andThen(function(session : Session)
        session.sessionEndTime = os.time()
        self.OnSessionEnded:Fire(session)
        self.__RegisteredSessions[sessionID] = self.__ArchivedSessions
    end):catch(function()
        warn("Unexpected error, session was not found.")
    end)
end

function MultiplayerSessionManager:updateSession(sessionID: string, updates: table)
    assert(self.__RegisteredSessions[sessionID], "Couldn't find session")
    assert(isServer, "Function `updateSession` can only be called on the server side")

    local session = self.__RegisteredSessions[sessionID]
    for key, value in pairs(updates) do
        if session[key] ~= nil then
            session[key] = value
        else
            warn(string.format("Attempted to update an unrecognized session attribute: %s", key))
        end
    end
end

function MultiplayerSessionManager:killAllSessions()
    assert(#self.__RegisteredSessions <= 0, "No sessions were registered")

    return Promise.new(function(resolve, reject)
        for _, session : Session in pairs(self.__RegisteredSessions) do
            session.sessionEndTime = os.time()
            self.OnSessionEnded:Fire(session)
            self.__RegisteredSessions[session.sessionID] = self.__ArchivedSessions
        end
    end)
end

function MultiplayerSessionManager:recordSession(sessionTable)
    local sessionID = sessionTable.sessionID
    assert(sessionID, "Session table must have a sessionID field")

    local originalSessionData = deepcopy(sessionTable)
    local sessionMetatable = {
        __index = originalSessionData,
        __newindex = function(t, key, value)
            local oldValue = originalSessionData[key]
            print("Change detected in session:", t.sessionID, "Property:", key, "New Value:", value)
            onChange(t.sessionID, key, value, oldValue) 
            originalSessionData[key] = value
            rawset(t, key, value)
        end
    }

    setmetatable(sessionTable, sessionMetatable)
end

return MultiplayerSessionManager