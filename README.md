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
