local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)
local Middleware = require(script.Parent.Parent.Middleware)
local Util = require(script.Parent.Parent.Util)

local DataStreams = {}

local GlobalDataStream = {}

type Self = {
    _id: number,
    _name: string,
    _data: unknown?,

    Changed: Signal.Signal<>
}

function GlobalDataStream.new(name: string)
    local self = {
        _id = Util.hashString("global" .. name),
        _name = name,
        Changed = Signal.new()
    }

    if DataStreams[self._id] then
        error(`A GlobalDataStream with the name "{name}" already exists`)
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
        end
    end)

    setmetatable(self, {__index = GlobalDataStream})
    return self
end

function GlobalDataStream.GetData(self: Self)
    assert(self._data ~= nil, `GlobalDataStream "{self._name}" does not contain any data`)

    return self._data
end

function GlobalDataStream.GetMutable()
    error("GlobalDataStream cannot be mutated from the client")
end

function GlobalDataStream.SetData()
    error("GlobalDataStream cannot be mutated from the client")
end

function GlobalDataStream.UpdateData()
    error("GlobalDataStream cannot be mutated from the client")
end

function GlobalDataStream.HasData(self: Self)
    return self._data ~= nil
end

function GlobalDataStream.Wait(self: Self)
    if self._data ~= nil then
        return self
    end

    local delay = task.delay(5, function()
        warn("Infinite yield possible on GlobalDataStream:Wait()")
    end)

    repeat
        self.Changed:Wait()
    until self._data ~= nil

    task.cancel(delay)
    return self
end

return GlobalDataStream