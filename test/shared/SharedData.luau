--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStream = require(ReplicatedStorage.Packages.DataStream)

return {
    RoundData = DataStream.global("RoundData", {} :: {
        TimeLeft: number
    }),
    PlayerData = DataStream.player("PlayerData", {} :: {
        Coins: number,
        Inventory: {string}
    }),
    MatchData = DataStream.player("MatchData", {} :: {
        IsMatch: boolean,
        TimeLeft: number
    })
}