# Bootstrap reviewer dispositions

Claude subscription smoke test succeeded with tool access disabled and a synthetic recovery-rule packet. Its CHANGES_REQUESTED verdict correctly observed that a rule-only packet cannot verify an implementation. That is accepted as a scope limitation, not an implementation failure. Actual behavior is covered by local regression tests; the selected source review remains pending after two timed-out retries.

Gemini text and image review protocol tests succeeded with `gemini-3.5-flash`. Gemini identified the demo fixture's tiny, off-center label; it is not production UI and is never uploaded by demo mode. The suggestion to replace the “DEMO — NO UPLOAD” placeholder is rejected for the test fixture: the label is deliberate. Suggestions requiring gradients or 3D depth for every UI container are rejected as an invented constraint; the art direction allows graphic flat treatments. No generated reviewer verdict grants production acceptance.

Figma inspection found no existing components, variables, styles, or canvas artwork. A disposable rectangle was created, inspected, removed, and the original empty canvas was verified. This establishes connector write access; it does not establish an art system or Studio visual acceptance.

The renewed source review attempts both timed out at 240 seconds. No Claude source findings exist to accept or reject. The narrower retry prompt described the cooperative same-user boundary as accepted for review scope; that wording is not user acceptance of the unmet universal human-only security requirement, which remains documented as unresolved. The later GUI-only scrollbar and bottom-button adjustment passed all offline and native callback tests.


Claude timeout diagnosis and successful review:

The prior pending review is resolved. The CLI connected and received its first API stream chunk in about one second; subscription rate-limit status was `allowed`. The stream then emitted generation-progress events while the former 240-second wrapper deadline expired. A source review with explicit medium effort completed successfully at `.review/claude-71ec77ff-bf9f-4ab6-8964-de6a6fad9770/review.txt`. The wrapper now uses medium effort, a configurable 900-second deadline, and stream-derived progress checkpoints every 15 seconds. It persists only phase, elapsed time, selected model, and rate-limit status, not reasoning text. A live wrapper smoke test completed in 12 seconds.

- Accepted: one invalid frozen request could abort the resume batch before later healthy requests were processed. `resume_requests` now records that request's error, continues other requests, and returns a failing exit status after the batch. A missing-file regression confirms a later known operation is still polled.
- Rejected: the reviewer called the known-operation exception branch dead code. `store.save(record)` immediately after assigning the operation can raise, and `poll` can also fail while persisting its error. Retaining the known operation in that handler remains necessary.
- Intentional: list/status/doctor recover interrupted transient state while holding the gate lock; a persisted APPROVED record never substitutes for fresh graphical approval.
- The later streaming smoke verdict correctly refused implementation approval for a synthetic requirement-only packet. It verifies the reviewer protocol, not source correctness.

Every popup now runs a foreground callback after mapping, briefly raises topmost, forces focus, and releases topmost after 500 ms. It does not repeatedly steal focus or activate an approval button. Three successive native demo windows confirmed focus and zero network writes. All 28 regressions passed.
