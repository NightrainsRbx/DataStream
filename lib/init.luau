--!nocheck

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local Environment = if RunService:IsClient() then script.Client else script.Server

local GlobalDataStream = require(Environment.GlobalDataStream)
local PlayerDataStream = require(Environment.PlayerDataStream)

local Middleware = require(script.Middleware)

type Signal<T...> = {
    Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Signal.Connection,
    Once: (self: Signal<T...>, fn: (T...) -> ()) -> Signal.Connection,
    Wait: (self: Signal<T...>) -> T...,
}

export type GlobalDataStream<T> = {
    GetData: (self: GlobalDataStream<T>) -> T,
    GetMutable: (self: GlobalDataStream<T>) -> T,
    SetData: (self: GlobalDataStream<T>, data: T) -> (),
    UpdateData: (self: GlobalDataStream<T>, (data: T) -> ()) -> (),
    HasData: (self: GlobalDataStream<T>) -> boolean,
    Wait: (self: GlobalDataStream<T>) -> GlobalDataStream<T>,
    Changed: Signal<>,
}

type DataId = number

export type PlayerDataStream<T> = {
    GetData: ((self: PlayerDataStream<T>, player: Player | DataId) -> T)
        & (self: PlayerDataStream<T>) -> T,
    GetMutable: (self: PlayerDataStream<T>, player: Player | DataId) -> T,
    GetId: (self: PlayerDataStream<T>, data: T) -> DataId,
    SetData: (self: PlayerDataStream<T>, player: Player, data: T | DataId) -> (),
    UpdateData: (self: PlayerDataStream<T>, player: Player | DataId, (data: T) -> ()) -> (),
    RemoveData: (self: PlayerDataStream<T>, player: Player | DataId) -> (),
    HasData: ((self: PlayerDataStream<T>, player: Player | DataId) -> boolean)
        & (self: PlayerDataStream<T>) -> boolean,
    Wait: ((self: PlayerDataStream<T>, player: Player | DataId) -> PlayerDataStream<T>)
        & (self: PlayerDataStream<T>) -> PlayerDataStream<T>,
    Changed: Signal<Player>,
    Removed: Signal<Player>
}

local DataStream = {}

function DataStream.global<T>(name: string, scheme: T?): GlobalDataStream<T>
    return GlobalDataStream.new(name)
end

function DataStream.player<T>(name: string, scheme: T?): PlayerDataStream<T>
    return PlayerDataStream.new(name)
end

function DataStream.middleware(
    methods: {
        FireAllClients: (...any) -> (),
        FireClient: (Player, ...any) -> (),
        OnServerInvoke: ((Player, ...any) -> any) -> (),
    } | {
        OnClientEvent: ((...any) -> ()) -> (),
        InvokeServer: (...any) -> any,
    }
)
    for key, value in methods do
        Middleware[key] = value
    end
    if RunService:IsServer() and assert(methods.OnServerInvoke ~= nil) then
        methods.OnServerInvoke(function(...)
            return GlobalDataStream.handleRequest(...) or PlayerDataStream.handleRequest(...)
        end)
    end
end

DataStream.middleware(Middleware)

DataStream.AutoRemovePlayers = true

if RunService:IsServer() then
    Players.PlayerRemoving:Connect(function(player)
        if not DataStream.AutoRemovePlayers then
            return
        end
        PlayerDataStream.handleRemoving(player)
    end)
end

return DataStream