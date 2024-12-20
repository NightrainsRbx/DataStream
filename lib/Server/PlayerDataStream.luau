--!nocheck

local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)
local Middleware = require(script.Parent.Parent.Middleware)
local Util = require(script.Parent.Parent.Util)

local PlayerDataStream = {}

type Self = {
    _id: number,
    _name: string,
    _data: {[Player | number]: unknown?},
    _copy: {[Player | number]: unknown?},
    _deferThread: {[Player | number]: thread?},
    _playerToDataId: {[Player]: number},

    Changed: Signal.Signal<Player>,
    Removed: Signal.Signal<Player>
}

local DataStreams: {Self} = {}

function PlayerDataStream.new(name: string)
    local self = {
        _id = Util.hashString("player" .. name),
        _name = name,
        _data = {},
        _copy = {},
        _deferThread = {},
        _playerToDataId = {},
        Changed = Signal.new(),
        Removed = Signal.new()
    }

    if DataStreams[self._id] then
        error(`A PlayerDataStream with the name "{name}" already exists`)
    end
    DataStreams[self._id] = self

    setmetatable(self, {__index = PlayerDataStream})

    return self
end

function PlayerDataStream.handleRequest(player, id)
    local dataStream = DataStreams[id]
    if not dataStream then
        return nil
    end
    return dataStream._data[dataStream._playerToDataId[player] or player]
end

function PlayerDataStream.handleRemoving(player)
    for _, dataStream in pairs(DataStreams) do
        if dataStream._data[dataStream._playerToDataId[player] or player] then
            dataStream.Removed:Fire(player)
        end
        dataStream._playerToDataId[player] = nil
        dataStream._data[player] = nil
        dataStream._copy[player] = nil
        if dataStream._deferThread[player] then
            task.cancel(dataStream._deferThread[player])
            dataStream._deferThread[player] = nil
        end
    end
end

function PlayerDataStream.GetData(self: Self, key: Player | number)
    assert(key ~= nil, `Argument "player" needs to be specified in the server`)

    if typeof(key) == "Instance" and key:IsA("Player") then
        assert(self._data[self._playerToDataId[key] or key] ~= nil, `PlayerDataStream "{self._name}" does not contain any data for player "{key.Name}"`)
    elseif type(key) == "number" then
        assert(self._data[key] ~= nil, `PlayerDataStream "{self._name}" does not contain any data with id "{key}"`)
    else
        error(`Argument "player" needs to be a Player or number, provided "{typeof(key)}"`)
    end

    key = self._playerToDataId[key] or key

    -- if self._deferThread[key] then
    --     coroutine.resume(self._deferThread[key] :: thread)
    -- end

    return self._data[key]
end

function PlayerDataStream.GetMutable(self: Self, key: Player | number)
    assert(key ~= nil, `Argument "player" needs to be specified in the server`)

    if typeof(key) == "Instance" and key:IsA("Player") then
        assert(self._data[self._playerToDataId[key] or key] ~= nil, `PlayerDataStream "{self._name}" does not contain any data for player "{key.Name}"`)
    elseif type(key) == "number" then
        assert(self._data[key] ~= nil, `PlayerDataStream "{self._name}" does not contain any data with id "{key}"`)
    else
        error(`Argument "player" needs to be a Player or number, provided "{typeof(key)}"`)
    end

    key = self._playerToDataId[key] or key

    if self._copy[key] == nil then
        self._copy[key] = Util.deepCopy(self._data[key])
    end

    local function defer(self: Self)
        if self._deferThread[key] then
            return
        end

        self._deferThread[key] = task.defer(function()
            local diff, _ = DeltaCompress.diffMutable(self._copy[key], self._data[key])
            if diff then
                if type(key) == "number" then
                    for player, dataId in self._playerToDataId do
                        if dataId == key then
                            self.Changed:Fire(player)
                            Middleware.FireClient(player, self._id, "update", diff)
                        end
                    end
                else
                    self.Changed:Fire(key)
                    Middleware.FireClient(key, self._id, "update", diff)
                end
            end
            self._deferThread[key] = nil
        end)
    end

    return setmetatable({}, {
        __index = function(_, index)
            defer(self)
            return self._data[key][index]
        end,
        __newindex = function(_, index, value)
            defer(self)
            self._data[key][index] = value
        end,
        __iter = function()
            defer(self)
            return next, self._data[key]
        end
    })
end

function PlayerDataStream.GetId(self: Self, data)
    assert(type(data) == "table", `Argument "data" needs to be a table, provided "{type(data)}"`)

    local dataId = Util.hashString(tostring(data))

    if not self._data[dataId] then
        self._data[dataId] = data
        self._copy[dataId] = Util.deepCopy(data)
    end

    return dataId
end

function PlayerDataStream.SetData(self: Self, player: Player, data)
    assert(player ~= nil, `Argument "player" needs to be specified in the server`)
    assert(type(data) == "table" or type(data) == "number", `Argument "data" needs to be a table or number, provided "{type(data)}"`)

    if type(data) == "number" then
        assert(self._data[data] ~= nil, `PlayerDataStream "{self._name}" does not contain any data with id "{data}"`)

        self._playerToDataId[player] = data
        self._data[player] = nil
        self._copy[player] = nil

        if self._deferThread[player] then
            task.cancel(self._deferThread[player])
            self._deferThread[player] = nil
        end

        self.Changed:Fire(player)
        Middleware.FireClient(player, self._id, "set", self._data[data])
        return
    end

    self._playerToDataId[player] = nil
    self._data[player] = data
    self._copy[player] = Util.deepCopy(data)

    if self._deferThread[player] then
        task.cancel(self._deferThread[player])
        self._deferThread[player] = nil
    end

    self.Changed:Fire(player)
    Middleware.FireClient(player, self._id, "set", self._data[player])
end

function PlayerDataStream.HasData(self: Self, key: Player | number)
    assert(key ~= nil, `Argument "player" needs to be specified in the server`)

    return self._data[self._playerToDataId[key] or key] ~= nil
end

function PlayerDataStream.RemoveData(self: Self, key: Player | number)
    assert(key ~= nil, `Argument "player" needs to be specified in the server`)

    self._data[key] = nil
    self._copy[key] = nil

    if self._deferThread[key] then
        task.cancel(self._deferThread[key])
        self._deferThread[key] = nil
    end

    if type(key) == "number" then
        for player, dataId in self._playerToDataId do
            if dataId == key then
                self._playerToDataId[player] = nil
                self.Removed:Fire(player)
                Middleware.FireClient(player, self._id, "remove")
            end
        end
    else
        self._playerToDataId[key] = nil
        self.Removed:Fire(key)
        Middleware.FireClient(key, self._id, "remove")
    end
end

function PlayerDataStream.Wait(self: Self, key: Player | number)
    assert(key ~= nil, `Argument "player" needs to be specified in the server`)

    if self._data[self._playerToDataId[key] or key] ~= nil then
        return self
    end

    local delay = task.delay(5, function()
        warn("Infinite yield possible on PlayerDataStream:Wait()")
    end)

    repeat
        self.Changed:Wait()
    until self._data[self._playerToDataId[key] or key] ~= nil

    task.cancel(delay)

    return self
end

return PlayerDataStream