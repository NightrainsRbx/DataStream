local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)

local ReceivedDataEvent = script.Parent.Parent.Server.PlayerDataStream:WaitForChild("RemoteEvent") :: RemoteEvent
local RequestDataFunction = script.Parent.Parent.Server.PlayerDataStream:WaitForChild("RemoteFunction") :: RemoteFunction

local DataStreams = {}

local PlayerDataStream = {}

type Self = {
    _name: string,
    _data: unknown?,
    _conn: RBXScriptConnection?,

    Changed: Signal.Signal<>,
    Removed: Signal.Signal<>
}

function PlayerDataStream.new(name: string)
    local self = {
        _name = name,
        Changed = Signal.new(),
        Removed = Signal.new()
    }

    if DataStreams[name] then
        error(`A PlayerDataStream with the name "{name}" already exists`)
    end
    DataStreams[name] = self

    self._data = RequestDataFunction:InvokeServer(name)

    self._conn = ReceivedDataEvent.OnClientEvent:Connect(function(dataName, method, data)
        if dataName ~= name then
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
        return
    end
    repeat
        self.Changed:Wait()
    until self._data ~= nil
end

return PlayerDataStream