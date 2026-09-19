-- Description: Re-export MatchSim from Game.Modes for backwards compatibility.

--!strict

local MatchSim = require(script.Parent.Parent.Modes.MatchSim)

export type MatchPhase = MatchSim.MatchPhase
export type MatchState = MatchSim.MatchState
export type MatchEvent = MatchSim.MatchEvent

return MatchSim
