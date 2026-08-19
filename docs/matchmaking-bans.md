# Matchmaking bans

Matchmaking bans live in the universe-wide DataStore `OuchMatchmakingBans_v1`, scope `global`. They do not prevent a player from joining the lobby; the server checks every party member immediately before the leader starts matchmaking.

Create one entry per banned player in Creator Hub's Data Stores Manager:

- Key: the player's numeric Roblox user ID as a string, such as `123456789`
- Permanent ban value: `0`
- Temporary ban value: `1780000000`, using a future Unix timestamp in seconds

An expiration value equal to or earlier than the current Unix time is ignored. Delete the entry to unban the player. Any non-integer, negative, or non-numeric value is invalid and prevents that party from entering matchmaking until the entry is corrected or removed.

The check fails closed if the DataStore cannot be read. The leader receives `MATCHMAKING COULD NOT BEGIN`; the response does not identify the banned party member.
