local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)

local ReceivedDataEvent = Instance.new("RemoteEvent", script)
local RequestDataFunction = Instance.new("RemoteFunction", script)

local DataStreams = {}

RequestDataFunction.OnServerInvoke = function(_, dataName)
    if not DataStreams[dataName] then
        return nil
    end
    return DataStreams[dataName]._data
end

local GlobalDataStream = {}

type Self = {
    _name: string,
    _data: unknown?,
    _copy: unknown?,
    _deferThread: thread?,

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

    setmetatable(self, {__index = GlobalDataStream})

    return self
end

function GlobalDataStream.GetData(self: Self)
    assert(self._data ~= nil, `GlobalDataStream "{self._name}" does not contain any data`)

    if self._deferThread then
        coroutine.resume(self._deferThread)
    end

    return self._data
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

function GlobalDataStream.GetDataMutable(self: Self)
    assert(self._data ~= nil, `GlobalDataStream "{self._name}" does not contain any data`)

    if self._copy == nil then
        self._copy = deepCopy(self._data)
    end

    local function defer()
        if self._deferThread then
            return
        end

        self._deferThread = task.defer(function()
            local diff, _ = DeltaCompress.diffMutable(self._copy, self._data)
            if diff then
                ReceivedDataEvent:FireAllClients(self._name, "update", diff)
                self.Changed:Fire()
                self._deferThread = nil
            end
        end)
    end

    return setmetatable({}, {
        __index = function(_, index)
            defer()
            return (self._data :: any)[index]
        end,
        __newindex = function(_, index, value)
            defer();
            (self._data :: any)[index] = value
        end,
        __iter = function()
            defer()
            return next, self._data
        end
    })
end

function GlobalDataStream.SetData(self: Self, data)
    assert(type(data) == "table", `Argument "data" needs to be a table, provided "{type(data)}"`)

    self._data = data
    self._copy = deepCopy(self._data)

    if self._deferThread then
        task.cancel(self._deferThread)
        self._deferThread = nil
    end

    self.Changed:Fire()

    ReceivedDataEvent:FireAllClients(self._name, "set", self._data)
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