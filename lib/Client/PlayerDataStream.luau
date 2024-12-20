local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)
local Middleware = require(script.Parent.Parent.Middleware)
local Util = require(script.Parent.Parent.Util)

local DataStreams = {}

local PlayerDataStream = {}

type Self = {
    _id: number,
    _name: string,
    _data: unknown?,

    Changed: Signal.Signal<>,
    Removed: Signal.Signal<>
}

function PlayerDataStream.new(name: string)
    local self = {
        _id = Util.hashString("player" .. name),
        _name = name,
        Changed = Signal.new(),
        Removed = Signal.new()
    }

    if DataStreams[self._id] then
        error(`A PlayerDataStream with the name "{name}" already exists`)
    end
    DataStreams[self._id] = self

    self._data = Middleware.InvokeServer(self._id)

    Middleware.OnClientEvent(function(id, method, data)
        if id ~= self._id then
            return
        end
        if method == "update" then
            if not self._data then
                return
            end
            DeltaCompress.applyMutable(self._data, data)
            self.Changed:Fire()
        elseif method == "set" then
            self._data = data
            self.Changed:Fire()
        elseif method == "remove" then
            self._data = nil
            self.Removed:Fire()
        end
    end)

    setmetatable(self, {__index = PlayerDataStream})
    return self
end

function PlayerDataStream.GetData(self: Self)
    assert(self._data ~= nil, `PlayerDataStream "{self._name}" does not contain any data`)

    return self._data
end

function PlayerDataStream.GetDataMutable()
    error("PlayerDataStream cannot be mutated from the client")
end

function PlayerDataStream.SetData()
    error("PlayerDataStream cannot be mutated from the client")
end

function PlayerDataStream.RemoveData()
    error("PlayerDataStream cannot be mutated from the client")
end

function PlayerDataStream.HasData(self: Self)
    return self._data ~= nil
end

function PlayerDataStream.Wait(self: Self)
    if self._data ~= nil then
        return self
    end
    local delay = task.delay(5, function()
        warn("Infinite yield possible on PlayerDataStream:Wait()")
    end)
    repeat
        self.Changed:Wait()
    until self._data ~= nil
    task.cancel(delay)
    return self
end

return PlayerDataStream