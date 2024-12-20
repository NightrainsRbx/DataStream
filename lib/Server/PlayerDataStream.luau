local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)
local Middleware = require(script.Parent.Parent.Middleware)
local Util = require(script.Parent.Parent.Util)

local DataStreams = {}

local PlayerDataStream = {}

type Self = {
    _id: number,
    _name: string,
    _data: {[Player]: unknown?},
    _copy: {[Player]: unknown?},
    _deferThread: {[Player]: thread?},

    Changed: Signal.Signal<Player>,
    Removed: Signal.Signal<Player>
}

function PlayerDataStream.new(name: string)
    local self = {
        _id = Util.hashString("player" .. name),
        _name = name,
        _data = {},
        _copy = {},
        _deferThread = {},
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
    if not DataStreams[id] then
        return nil
    end
    return DataStreams[id]._data[player]
end

function PlayerDataStream.GetData(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)
    assert(self._data[player] ~= nil, `PlayerDataStream "{self._name}" does not contain any data for player "{player.Name}"`)

    if self._deferThread[player] then
        coroutine.resume(self._deferThread[player] :: thread)
    end

    return self._data[player]
end

function PlayerDataStream.GetDataMutable(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)
    assert(self._data[player] ~= nil, `PlayerDataStream "{self._name}" does not contain any data for player "{player.Name}"`)

    if self._copy[player] == nil then
        self._copy[player] = Util.deepCopy(self._data[player])
    end

    local function defer(self: Self)
        if self._deferThread[player] then
            return
        end

        self._deferThread[player] = task.defer(function()
            local diff, _ = DeltaCompress.diffMutable(self._copy[player], self._data[player])
            if diff then
                Middleware.FireClient(player, self._id, "update", diff)
                self.Changed:Fire(player)
                self._deferThread[player] = nil
            end
        end)
    end

    return setmetatable({}, {
        __index = function(_, index)
            defer(self)
            return (self._data[player] :: any)[index]
        end,
        __newindex = function(_, index, value)
            defer(self);
            (self._data[player] :: any)[index] = value
        end,
        __iter = function()
            defer(self)
            return next, self._data[player]
        end
    })
end

function PlayerDataStream.SetData(self: Self, player: Player, data)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)
    assert(type(data) == "table", `Argument "data" needs to be a table, provided "{type(data)}"`)

    self._data[player] = data
    self._copy[player] = Util.deepCopy(self._data[player])

    if self._deferThread[player] then
        task.cancel(self._deferThread[player] :: thread)
        self._deferThread[player] = nil
    end

    self.Changed:Fire(player)

    Middleware.FireClient(player, self._id, "set", self._data[player])
end

function PlayerDataStream.HasData(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)

    return self._data[player] ~= nil
end

function PlayerDataStream.RemoveData(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)

    if self._data[player] == nil then
        return
    end

    self._data[player] = nil
    self._copy[player] = nil

    if self._deferThread[player] then
        task.cancel(self._deferThread[player] :: thread)
        self._deferThread[player] = nil
    end

    self.Removed:Fire(player)

    Middleware.FireClient(player, self._id, "remove")
end

function PlayerDataStream.Wait(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)

    if self._data[player] ~= nil then
        return self
    end
    local delay = task.delay(5, function()
        warn("Infinite yield possible on PlayerDataStream:Wait()")
    end)
    repeat
        self.Changed:Wait()
    until self._data[player] ~= nil
    task.cancel(delay)
    return self
end

return PlayerDataStream