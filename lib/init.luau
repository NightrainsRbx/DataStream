local RunService = game:GetService("RunService")

local Signal = require(script.Parent.Signal)

local Environment = if RunService:IsClient() then script.Client else script.Server

local GlobalDataStream = require(Environment.GlobalDataStream) :: any
local PlayerDataStream = require(Environment.PlayerDataStream) :: any

type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Signal.Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Signal.Connection,
	Wait: (self: Signal<T...>) -> T...,
}

export type GlobalDataStream<T> = {
    GetData: (self: GlobalDataStream<T>) -> T,
    GetDataMutable: (self: GlobalDataStream<T>) -> T,
    SetData: (self: GlobalDataStream<T>, data: T) -> (),
    HasData: (self: GlobalDataStream<T>) -> boolean,
    Wait: (self: GlobalDataStream<T>) -> GlobalDataStream<T>,
    Changed: Signal<>,
}

export type PlayerDataStream<T> = {
    GetData: (self: PlayerDataStream<T>, player: Player?) -> T,
    GetDataMutable: (self: PlayerDataStream<T>, player: Player) -> T,
    SetData: (self: PlayerDataStream<T>, player: Player, data: T) -> (),
    RemoveData: (self: PlayerDataStream<T>, player: Player) -> (),
    HasData: (self: GlobalDataStream<T>, player: Player?) -> boolean,
    Wait: (self: PlayerDataStream<T>, player: Player?) -> PlayerDataStream<T>,
    Changed: Signal<Player>,
    Removed: Signal<Player>
}

local DataStream = {}

function DataStream.global<T>(name: string, scheme: T?): GlobalDataStream<T>
    return GlobalDataStream.new(name) :: any
end

function DataStream.player<T>(name: string, scheme: T?): PlayerDataStream<T>
    return PlayerDataStream.new(name) :: any
end

return DataStream