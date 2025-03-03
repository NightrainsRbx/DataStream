--!nocheck

local DeltaCompress = require(script.Parent.Parent.Parent.DeltaCompress)
local Signal = require(script.Parent.Parent.Parent.Signal)
local Middleware = require(script.Parent.Parent.Middleware)
local Util = require(script.Parent.Parent.Util)

local GlobalDataStream = {}

type Self = {
    _id: number,
    _name: string,
    _data: unknown?,
    _copy: unknown?,
    _deferThread: thread?,

    Changed: Signal.Signal<>
}

local DataStreams: {Self}= {}

function GlobalDataStream.new(name: string)
    local self = {
        _id = Util.hashString("global" .. name),
        _name = name,
        _data = nil,
        Changed = Signal.new()
    }

    if DataStreams[self._id] then
        error(`A GlobalDataStream with the name "{name}" already exists`)
    end
    DataStreams[self._id] = self

    setmetatable(self, {__index = GlobalDataStream})

    return self
end

function GlobalDataStream.handleRequest(_, id)
    if not DataStreams[id] then
        return nil
    end
    return DataStreams[id]._data
end

function GlobalDataStream.GetData(self: Self)
    assert(self._data ~= nil, `GlobalDataStream "{self._name}" does not contain any data`)

    -- if self._deferThread then
    --     coroutine.resume(self._deferThread)
    -- end

    return self._data
end

function GlobalDataStream.GetMutable(self: Self)
    assert(self._data ~= nil, `GlobalDataStream "{self._name}" does not contain any data`)

    if self._copy == nil then
        self._copy = Util.deepCopy(self._data)
    end

    local function defer(self: Self)
        if self._deferThread then
            return
        end

        self._deferThread = task.defer(function()
            local diff, _ = DeltaCompress.diffMutable(self._copy, self._data)
            if diff then
                self.Changed:Fire()
                Middleware.FireAllClients(self._id, "update", diff)
            end
            self._deferThread = nil
        end)
    end

    return setmetatable({}, {
        __index = function(_, index)
            defer(self)
            return self._data[index]
        end,
        __newindex = function(_, index, value)
            defer(self)
            self._data[index] = value
        end,
        __iter = function()
            defer(self)
            return next, self._data
        end
    })
end

function GlobalDataStream.SetData(self: Self, data)
    assert(type(data) == "table", `Argument "data" needs to be a table, provided "{type(data)}"`)

    self._data = data
    self._copy = Util.deepCopy(data)

    if self._deferThread then
        task.cancel(self._deferThread)
        self._deferThread = nil
    end

    self.Changed:Fire()
    Middleware.FireAllClients(self._id, "set", self._data)
end

function GlobalDataStream.UpdateData(self: Self, callback)
    assert(type(callback) == "function", `Argument "callback" needs to be a function, provided "{type(callback)}"`)

    local copy = Util.deepCopy(self._data)
    local finished = false
    task.defer(function()
        if not finished then
            warn("GlobalDataStream:UpdateData() yielded")
        end
    end)
    callback(copy)
    finished = true

    local diff = DeltaCompress.diffMutable(self._data, copy)
    if diff then
        self._copy = copy
        self.Changed:Fire()
        Middleware.FireAllClients(self._id, "update", diff)
    end
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