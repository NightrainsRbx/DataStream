local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)

local ReceivedDataEvent = Instance.new("RemoteEvent", script)
local RequestDataFunction = Instance.new("RemoteFunction", script)

local DataStreams = {}

RequestDataFunction.OnServerInvoke = function(player, dataName)
    if not DataStreams[dataName] then
        return nil
    end
    return DataStreams[dataName]._data[player]
end

local PlayerDataStream = {}

type Self = {
    _name: string,
    _data: {[Player]: unknown?},
    _copy: {[Player]: unknown?},
    _deferThread: {[Player]: thread?},

    Changed: Signal.Signal<Player>,
    Removed: Signal.Signal<Player>
}

function PlayerDataStream.new(name: string)
    local self = {
        _name = name,
        _data = {},
        _copy = {},
        _deferThread = {},
        Changed = Signal.new(),
        Removed = Signal.new()
    }

    if DataStreams[name] then
        error(`A PlayerDataStream with the name "{name}" already exists`)
    end
    DataStreams[name] = self

    setmetatable(self, {__index = PlayerDataStream})

    return self
end

function PlayerDataStream.GetData(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)
    assert(self._data[player] ~= nil, `PlayerDataStream "{self._name}" does not contain any data for player "{player.Name}"`)

    if self._deferThread[player] then
        coroutine.resume(self._deferThread[player] :: thread)
    end

    return self._data[player]
end

local function deepCopy(tbl: any): any
    if type(tbl) ~= "table" then
        return nil
    end

    local copy = table.clone(tbl)

    for key, value in tbl do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        end
    end

    return copy
end

function PlayerDataStream.GetDataMutable(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)
    assert(self._data[player] ~= nil, `PlayerDataStream "{self._name}" does not contain any data for player "{player.Name}"`)

    if self._copy[player] == nil then
        self._copy[player] = deepCopy(self._data[player])
    end

    local function defer()
        if self._deferThread[player] then
            return
        end

        self._deferThread[player] = task.defer(function()
            local diff, _ = DeltaCompress.diffMutable(self._copy[player], self._data[player])
            if diff then
                ReceivedDataEvent:FireClient(player, self._name, "update", diff)
                self.Changed:Fire(player)
                self._deferThread[player] = nil
            end
        end)
    end

    return setmetatable({}, {
        __index = function(_, index)
            defer()
            return (self._data[player] :: any)[index]
        end,
        __newindex = function(_, index, value)
            defer();
            (self._data[player] :: any)[index] = value
        end,
        __iter = function()
            defer()
            return next, self._data[player]
        end
    })
end

function PlayerDataStream.SetData(self: Self, player: Player, data)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)
    assert(type(data) == "table", `Argument "data" needs to be a table, provided "{type(data)}"`)

    self._data[player] = data
    self._copy[player] = deepCopy(self._data[player])

    if self._deferThread[player] then
        task.cancel(self._deferThread[player] :: thread)
        self._deferThread[player] = nil
    end

    self.Changed:Fire(player)

    ReceivedDataEvent:FireClient(player, self._name, "set", self._data[player])
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

    ReceivedDataEvent:FireClient(player, self._name, "remove")
end

function PlayerDataStream.Wait(self: Self, player: Player)
    assert(player :: any ~= nil, `Argument "player" needs to be specified in the server`)

    if self._data[player] ~= nil then
        return
    end
    repeat
        self.Changed:Wait()
    until self._data[player] ~= nil
end

return PlayerDataStream