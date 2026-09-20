# Architecture

## 1. Overview
Ouch! is a Roblox multiplayer game with two game modes (Arena PvP brawling and Splashdown obstacle course racing), a lobby with matchmaking, and a candy-themed UI. It uses Rojo for file sync, Wally for packages, React for UI, and ProfileStore for player data.

## 2. Two-Place Model
The game runs as two separate Roblox places. Players teleport between them via the matchmaking system.

| Place | Place ID | Rojo Port | Rojo Project File | Responsibilities |
| --- | --- | --- | --- | --- |
| **Lobby** | `130584867985467` | `34873` | [`lobby.project.json`](file:///lobby.project.json) | Social hub, matchmaking, party system, shop, backpack, settings, onboarding. |
| **Arena** | `121997450145716` | `34872` | [`arena.project.json`](file:///arena.project.json) | Combat matches, Splashdown races, post-match results. |

## 3. Source Layout
The repository is structured to share common modules while keeping place-specific features separate.

* **`src/shared/`** — Code shared between both places (Game systems, UI utilities, Tests).
* **`src/server/`** — Server modules shared across places (e.g., `PlayerData`).
* **`src/client/`** — Client code (e.g., `CombatClient`, `PlayerModule`).
* **`src/config/`** — All game configuration logic. Categories include:
  * `Cosmetics`
  * `Economy`
  * `Gameplay`
  * `Infra`
  * `Interface`
  * `Progression`
* **`places/arena/`** — Arena-specific server, client, and test code.
* **`places/lobby/`** — Lobby-specific server, client, and test code.
* **`src/scripts/`** — Lune build/release scripts, Studio authoring scripts.
* **`src/tests/`** — Shared test infrastructure.
* **`tools/`** — Python tooling (asset pipeline, visual review, deployment).
* **`generated/`** — Auto-generated build artifacts.

## 4. Rojo Project Composition
The DataModel is composed dynamically from scattered source paths via Rojo project files.

* **Shared Folders:** Both places share `src/shared` → `ReplicatedStorage.Shared`, `src/config` → `ReplicatedStorage.Config`, and `Packages` → `ReplicatedStorage.Packages`.
* **Server Modules:** Both places map the same server modules from `src/server/Modules/` individually into their `ServerScriptService.Server.Modules` folder. **When adding a new shared server module, it must be added to both `arena.project.json` and `lobby.project.json`.**
* **Place-Specific Code:** Specific implementations live under `places/{arena,lobby}/`.
* **Matchmaking:** The lobby has its own `places/lobby/shared/Matchmaking/` mapped directly into `ReplicatedStorage.Shared.Matchmaking`.
* **Tests:** `tests.project.json` reuses the arena layout for running the test suite.
* **Exclusions:** `globIgnorePaths` excludes test specs and UI stories from being served into the game.

## 5. Server/Client Boundary
The remote event/function setup is centralized in [`src/shared/Network.luau`](file:///src/shared/Network.luau).

* **Server:** Authoritative for combat simulation, player data, economy, and progression.
* **Client:** Owns input, camera, presentation, and UI rendering.
* **Data Flow:** [`src/shared/Game/Data/ReplicatedStore.luau`](file:///src/shared/Game/Data/ReplicatedStore.luau) and [`src/shared/Game/Data/ClientRequest.luau`](file:///src/shared/Game/Data/ClientRequest.luau) handle client-server data flow.
* **ProfileStore Pattern:** Read [`src/server/Modules/PlayerData.luau`](file:///src/server/Modules/PlayerData.luau) to understand how the profile replication and saving is handled. It utilizes write-through proxies and Replica to synchronize data mutations.

## 6. Data Flow

* **Player Data:** Loaded via ProfileStore in the server `PlayerData` module, then exposed through ReplicatedStore using Replica for automatic client synchronization.
* **Config:** Loaded at startup from `src/config/`. The `ConfigLiveService` on the server handles runtime overrides, and the client replicates this state.
* **Economy:** Owned by the server. The client reads replicated balance and transaction state.
* **UI:** React components read from stores/contexts. They dispatch actions or remote requests and never mutate server state directly.

## 7. Package Dependencies
Core packages defined in [`wally.toml`](file:///wally.toml):

* **`react` + `react-roblox`** — React 17 for UI architecture.
* **`react-spring`** — UI animation.
* **`promise`** — Asynchronous flow control.
* **`profilestore`** — Player data persistence.
* **`replica`** — State replication for data profiles.
* **`testEZ`** — Testing framework.
* **`cmdr`** — Admin commands.
* **`camera-shaker`** — Utility for camera effects.
