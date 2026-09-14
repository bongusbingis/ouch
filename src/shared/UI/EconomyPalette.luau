--!strict
-- Compatibility roles for economy views, all resolved from the approved tokens.
local T = require(script.Parent.Tokens)
local C = T.Colors
local colors = table.clone(C)
colors.White = C.Surface
colors.Panel = C.SurfaceWarm
colors.PanelRaised = C.Well
colors.Claimed = C.WellLine
colors.Disabled = C.WellLine
colors.Track = C.WellLine
return table.freeze(colors)
