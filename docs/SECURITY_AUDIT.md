# Bootstrap asset-write audit

Audit performed on 2026-09-08. No real Roblox upload was performed.

Search repository source (including hidden source/configuration, excluding dependencies, Git internals, binary places, and ignored scratch) for `apis.roblox.com`, `/assets/v1/assets`, `x-api-key`, and `roblox-asset-gate-opencloud`. Also inspect `rbxcloud`, `publish`, and `upload` call sites because CLI wrappers can hide URLs.

| Location | Classification |
| --- | --- |
| tools/gate_runtime.py | New content POST/PATCH and operation GET. Credential lookup and network execution require the fixed installed external path. Production write exists only inside the fresh GUI decision callback. Repository execution refuses credential access. |
| tools/assetctl.py | Prepares local requests; invokes installed gate; reconciles results. No keyring import or HTTP upload client. |
| tools/doctor.py | Retrieves Gemini credential presence; asks installed gate for Roblox credential presence. No Roblox credential lookup. |
| tools/install_asset_gate.py | Copies reviewable code and installs packages under LOCALAPPDATA; no Roblox credential or upload. |
| liveconfig.py | Existing creator-configs API read/write. Configuration is separate from Assets API content. Unchanged. |
| src/scripts/lune/fetch-live-place.luau | Existing asset-delivery GET for published places. Unchanged. |
| src/scripts/lune/test-and-deploy.luau | Existing cloud/v2 GET and rbxcloud place-version publication/test execution. Unchanged; separate existing production release boundary. |
| src/scripts/lune/release-places.luau and .github/workflows/cicd.yml | Existing staged/tested place publishing. Unchanged; no new standalone asset upload path. |

The user explicitly confirmed that the gate covers standalone asset uploads and that existing place CI must be preserved. Place-version publishing remains under that existing release boundary. The bootstrap never invoked those publishing paths.

The runtime source is present for review and installation, but cannot upload when executed from the repository. This is a cooperative workflow restriction. Because installation, credentials, and automation share the Windows user, it is not protection against arbitrary malicious same-user Python, file edits, or injected GUI clicks. No claim of unforgeable human approval is made. See ASSET_PIPELINE.md.

Local regression evidence covers sanitized Claude environment, neutral/no-tools CLI invocation, restricted licensing, frozen hash/metadata invalidation, exact transmitted bytes and metadata with mocked transport, zero-network demo approval and production denial, window-close persistence, operation retention, non-retry after uncertain errors, durable SQLite after forced exit, deterministic credits, and idempotent reconciliation. The installed demo process was also terminated and recovered with the same hash.

External Claude source review was retried twice under the renewed user request; both attempts timed out. No source-review verdict is claimed. Local regression evidence remains valid.

The newly connected Studio MCP exposes an `upload_image` tool capable of bypassing this cooperative routing policy. It was not invoked. Studio MCP is for inspection and integration; standalone asset creation/update must use the external gate. This is another reason the same-user workflow cannot provide an adversarial universal guarantee.
