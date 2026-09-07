# UI detail polish and world podium

This pass preserves the shop section order, the bright cyan/pink/yellow palette, rounded controls, bold display type, and the existing economy and match owners. Mobile QA targets landscape; portrait handling remains in place.

## Player-facing changes

- Shop cards share name sizes, wrapping, action heights, and insets. The Bonks balance is an icon and amount without the black outline box. Short landscape windows use the existing split-card composition with a complete action row visible. Larger windows retain the dashboard arrangement.
- Purchase details say what is being bought: **BUY OUTFIT**, **BUY ITEM**, or the relevant pass/bundle action. Price and currency icon are fitted as one group. The balance is labelled **YOUR BONKS**. Generic filler such as “Yours to keep” has been removed.
- Seasons have separate **FREE** and **PREMIUM** reward browsers, explicit tier requirements, item previews, and claim states. **GET PREMIUM PASS** buys access to the premium track; **CLAIM REWARDS** collects earned rewards. Empty free/premium tier cells are gone. Phones show a horizontal reward strip and open a selected reward in a full preview with a **REWARDS** return action.
- Party controls use the same rounded surface. Daily and season entry buttons use the shared pink treatment. Settings descriptions have stronger contrast. Backpack item names have consistent bands and fit a complete row on short screens.
- Currency labels fit the icon and amount together. Item previews frame their bounds when the viewport changes. Vote cards have actual character art when a thumbnail has not been configured, complete vote labels, and readable win conditions.
- Quest claims use the server's public `questId` field. The adapter rejects invalid keys before indexing pending state. The loading/onboarding subscription also rechecks the current state after subscribing, avoiding a missed completion that left the lobby invisible.

Robux amounts continue to come from client Marketplace product information. QA fixtures contain no invented Robux prices, and purchase prompts were not used for visual testing.

## Season conventions and rationale

[Fall Guys' Fame Pass](https://www.fallguys.com/fame-pass) distinguishes the free progression path from paid access to additional earnable rewards. [Fortnite's pass documentation](https://www.epicgames.com/help/c-34254770/c-Trending_0/a19736825) distinguishes XP progress, reward claiming, and premium access. [Rocket League's Rocket Pass](https://www.epicgames.com/help/c-37599050/c-32343914/a22907429) uses an explicit Get Premium action and grants access to rewards at already-earned tiers.

The resulting design decision here is to keep the progression requirement visible beside the reward and name the purchase after the pass. This makes the offer understandable without suggesting that buying the pass immediately unlocks every future tier. The existing server still decides eligibility, purchases, and grants; the browser derives its state from that projection.

## World podium

Both places contain the authored template `ReplicatedStorage.Assets.UI.ResultsStage`. It has a patterned backdrop, deck, three coloured numbered pillars, avatar markers, and a small confetti template. `src/scripts/studio/author-results-stage.luau` records the Studio authoring recipe and refuses to overwrite an existing stage.

`PostMatchScene` clones this template into the local Workspace for results. `VictoryRig` clones the existing character rig and applies the result's colour and outfit. Characters stand on the physical pillars and play the shared emote poses. If the player remains connected, the scene reads the existing `Equip_EmoteAssets` projection so subsequent emote changes appear on the podium. A disconnected player's result appearance remains usable.

The scene uses the existing `PresentationCamera` lease owner, at results priority between death and vote cameras. Camera framing accounts for the portion of the viewport available beside results UI. Scores, rewards, replay and lobby actions remain in the existing post-match flow. Opening scores retains the world scene; ending results destroys the clone, cancels preparation and releases the camera lease. Gameplay characters are not teleported to or controlled by the display stage.

Confetti uses a bounded set of template clones updated with the podium poses. Reduced motion disables confetti and uses the shared reduced-motion pose. The future emote radial should use the existing validated emote selection path; this pass does not introduce a second inventory or emote owner.

## Verification

- Headless suite: 712 tests, zero failures.
- Shared, lobby and arena lint checks: zero errors or warnings.
- Engine checks: 11 passed in each place, zero failures. They cover the public quest callback/pending contract, scrolling selection, desktop/phone camera projection, currency fitting, complete authored stage hierarchy, and world emote bounds.
- Visual checks use the real components and native lobby, with desktop, tablet, and landscape phone simulation. Screens reviewed include shop, purchase details, crate odds/reveal, seasons, backpack, settings, party/join, daily rewards, notifications, mode vote, loading/onboarding, combat HUD and post-match podium/scores.
- Arena scene probes verify live equipped-emote projection, bounded confetti, empty and tied results, safe camera preemption, and idempotent cleanup. The lobby probe also verifies camera restoration after cleanup.
- Both explicit Rojo project builds and all three format checks passed. `git diff --check` passed.

The Studio assets must travel with the source changes. The lobby was saved to Roblox as an unpublished draft on September 6, 2026, at 20:22:39 Studio time. The arena remains open in Edit with its authored stage; its save is still pending because native window access returned `noWindowsAvailable`, although MCP remains responsive. The saved lobby window was closed during window recovery and needs reopening with `lobby.project.json` on port 34873. Save the arena through Studio before closing it. No repository tool edited the authored place binaries, and nothing was published.

Studio validation and saved drafts do not constitute a published multiplayer or real-purchase test.
