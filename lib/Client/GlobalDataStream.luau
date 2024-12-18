local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)

local ReceivedDataEvent = script.Parent.Parent.Server.GlobalDataStream:WaitForChild("RemoteEvent") :: RemoteEvent
local RequestDataFunction = script.Parent.Parent.Server.GlobalDataStream:WaitForChild("RemoteFunction") :: RemoteFunction

local DataStreams = {}

local GlobalDataStream = {}

type Self = {
    _name: string,
    _data: unknown?,
    _conn: RBXScriptConnection?,

    Changed: Signal.Signal<>
}

function GlobalDataStream.new(name: string)
    local self = {
        _name = name,
        Changed = Signal.new()
    }

    if DataStreams[name] then
        error(`A GlobalDataStream with the name "{name}" already exists`)
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
        end
    end)

    setmetatable(self, {__index = GlobalDataStream})
    return self
end

function GlobalDataStream.GetData(self: Self)
    assert(self._data ~= nil, `GlobalDataStream "{self._name}" does not contain any data`)

    return self._data
end

function GlobalDataStream.GetDataMutable()
    error("GlobalDataStream cannot be mutated from the client")
end

function GlobalDataStream.SetData()
    error("GlobalDataStream cannot be mutated from the client")
end

function GlobalDataStream.HasData(self: Self)
    return self._data ~= nil
end

function GlobalDataStream.Wait(self: Self)
    if self._data ~= nil then
        return
    end
    repeat
        self.Changed:Wait()
    until self._data ~= nil
end

return GlobalDataStream