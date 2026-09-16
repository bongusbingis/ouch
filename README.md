# Ouch

This repository is the source of truth for both places in the Ouch experience.

| Place | Place ID | Rojo project | Port |
|---|---:|---|---:|
| Arena | `121997450145716` | `arena.project.json` | `34872` |
| Lobby | `130584867985467` | `lobby.project.json` | `34873` |

Install dependencies once from this repository:

```sh
wally install
```

Serve the place you intentionally opened in Studio:

```sh
rojo serve arena.project.json
rojo serve lobby.project.json
```

The projects use both `servePlaceIds` and reciprocal `blockedPlaceIds`, so the
arena project cannot sync into the lobby and the lobby project cannot sync into
the arena. There is deliberately no `default.project.json`.

Canonical shared configuration and inventory/data systems live under
`src/config`, `src/shared`, and `src/server/Modules`. Lobby-only matchmaking and
presentation code lives under `places/lobby`.

## Game modes and queues

The lobby offers two matchmaking queues (`src/config/Gameplay/Queues.luau`):
`Arena` votes between the brawl modes, and `Splashdown` runs a fixed
Fall Guys-style race of three rounds over three of seven obstacle courses. Both
play in the Match Place; a Splashdown server parks the arena interior and
stands the round's course inside the stadium bowl. The course templates are
authored into `ReplicatedStorage.Assets.Maps.Splashdown` from the declarative
specs in `src/shared/Game/Splashdown/CourseSpecs/`, through the Command Bar
lines documented in `src/scripts/studio/author-splashdown-v2.luau` (run in
Studio Edit mode),
the race is owned by `places/arena/server/Modules/Splashdown/`, and
`Debug.StudioQueue` in `src/config/Infra/Debug.luau` picks which queue a Studio
play session pretends it came from.

### Quiet queues

Matchmaking favors fuller matches while bounding the time spent waiting for
more players. Splashdown's required roster falls from 30 immediately, to 20 at
5 seconds, 12 at 10 seconds, 8 at 15 seconds, 4 at 20 seconds, and 2 at 30 seconds.
Arena retains its 20/16/12/8/2 ladder over 30 seconds.

Both queues explicitly fall back to `MinPlayers = 2` at `MaxWaitSeconds = 30`,
even if a population ladder is later edited incorrectly. Age comes from the
oldest successfully claimed ticket, across lobby servers, and survives refreshes
and released claims. Full matches can start immediately; a single player still
waits for an opponent. Workers poll every 2 seconds, and reservation, service
retries, teleport, and loading add time beyond the population wait.

Run `lune run src/scripts/lune/probe-matchmaking-capacity.luau` for the offline
matchmaking scenarios, including two solo players across lobby workers, queue
refresh/retry recovery, and two-player arena admission. Evidence is written to
`.review/matchmaking/population-and-capacity.json`; cloud latency and players
are simulated.
