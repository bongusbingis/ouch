# Showtime

Pass **1970065084** adds three permanent victory emotes: **Confetti Twirl**, **Champion Flex**, and **Party Bounce**. They play on earned podium positions and the owner's personal result card. Everyone has a complete free **Victory Wave**. On short landscape screens, personal earnings stay above the fold and the personal celebration is in the same scrollable card.

This is the only new pass added by the arena redesign. It grants no boost, score, stage priority, combat visibility, weapon statistic, matchmaking preference or movement advantage. Its value is repeatable social expression using the player's equipped look. Conversion and retention benefits are hypotheses to measure, not guaranteed results.

## Complete product path

| Step | Existing owner and implementation |
|---|---|
| Discovery | Existing shop pass card and details modal; a quiet results-card hint points to Shop and Backpack. No automatic prompt or purchase interruption during Results. |
| Preview | One live avatar, three selectable style buttons, and the same renderer used in Backpack and Results. |
| Price and availability | `ShopClient` fetches client Marketplace product information. No Robux price is configured, mocked, or substituted when unavailable. Regional pricing remains platform-owned. |
| Explicit purchase | Existing game-pass prompt path using ID 1970065084. Off-sale/unavailable metadata does not expose a purchase action. |
| Fulfillment | `GamePassService` verifies platform ownership, reconciles on join and purchase, and grants the three configured IDs through `CosmeticsService`. Partial grants retry; already-owned items do not duplicate. |
| Persistence | Existing `Cosmetics.Owned` and `Cosmetics.Equipped.EmoteAssets`. No new profile field, currency or migration is needed. Existing empty/default equips remain valid. |
| Selection | Existing Backpack → Emotes tab and protected `EquipCosmetic` request. A nonowner cannot equip a paid style. Selecting Victory Wave restores the free default. |
| Result appearance | `MatchService` captures read-only equip attributes in the contestant roster. The validated result packet supplies appearance to the podium and personal card. Departed contestants retain their captured appearance. |
| Recovery | Ownership lookup/partial fulfillment retries while connected and on later joins. Purchase notification explains where the emotes are. Bounded equip requests recover from timeouts without optimistic profile writes. |
| Analytics | Existing offer-selected/prompt events, server `CosmeticGranted` events with pass/item IDs, and `CosmeticEquipped`. Already-owned reconciliation emits no extra grant event. |

Internal cosmetic IDs are `ShowtimeTwirl`, `ShowtimeFlex`, and `ShowtimeBounce`; these are persistent identities and must not be renamed after launch. All are Exclusive and excluded from crates and rotating Bonks offers. The existing default and three paid styles use `Emotes` config and the pure `VictoryPose` sampler.

`VictoryRig` clones the authored R15 preview rig and removes physics/animation controllers from that clone before posing its attachment graph. The live character is untouched. One shared visible-only preview scheduler caps updates at 30 Hz, pauses hidden previews and unregisters on teardown. Reduced Motion uses a static pose without falling confetti.

## Studio asset dependency

Both places require the completed `ReplicatedStorage.Assets.Rigs.CharacterRig`, including LeftFoot. The missing foot was repaired in both open Studio documents. Its exact mesh, maps and attachment requirements are recorded in [Studio setup](dodgeball-studio-setup.md#victory-emote-preview-rig). The new shared in-place rig spec validates every style and cleanup.

Studio asset changes must be saved through Studio and included in the place assets used by deployment. They are not contained in a Rojo source-only build; repository tooling has not edited either `.rbxl` or the user's `gameassets-renamed.rbxmx`.

## Validation and launch

- Pure regression covers all three catalog grants, the free default, existing inventory/equip rules, rejection of unowned equips, crate exclusion, looping poses and Reduced Motion.
- The actual Showtime catalog was tested through `GamePassService` with a failing middle grant, retry and repeated purchase-completion events: three unique grants, three grant events and one notification.
- Both Studio places rendered the complete rig. Shop preview buttons changed styles, and a fixture-only Backpack selection moved the equipped checkmark to Party Bounce without writing test ownership into the real profile.
- Studio checked three-person podiums on desktop/tablet and short landscape, the live single-person result packet, and visible/hidden/unregistered preview updates. Real billing and cross-server entitlement reconciliation remain release checks; no purchase was made during QA.

Suggested Dashboard name: **Showtime**. Suggested description: **Celebrate your way with three exclusive victory emotes. Play them on your result card and every podium you earn. Choose your celebration in Backpack → Emotes.**

The platform stub was inspected as `new`, **off sale**. Its sale status, price and icon were not changed. The configured icon is a sizing placeholder as requested. Set the name, icon, sale availability and regional/optimized price in Creator Dashboard when releasing. Validate at least two regional accounts against the native prompt. The game contains no assumed launch price.
