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
Fall Guys-style race of three rounds over three of five obstacle courses. Both
play in the Match Place; a Splashdown server parks the arena interior and
stands the round's course inside the stadium bowl. The course templates are
authored into `ReplicatedStorage.Assets.Maps.Splashdown` by
`src/scripts/studio/author-splashdown-courses.luau` (run in Studio Edit mode),
the race is owned by `places/arena/server/Modules/Splashdown/`, and
`Debug.StudioQueue` in `src/config/Infra/Debug.luau` picks which queue a Studio
play session pretends it came from.
