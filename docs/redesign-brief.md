# Shop screen redesign brief

## Scope
Redesign ONLY the shop screen. Do not touch game logic, routing, or any
other screen. Do not add dependencies.

## Keep (non-negotiable)
- Existing design tokens in /STYLE.md. Use them; do not introduce new hex values.
- The established art direction: thick outlines, chunky rounded cards,
  saturated palette, heavy display type. This is a kids' game; it should
  stay loud.
- All current functionality: currency display, Get Bonks CTA, season pass
  progress, featured/for-you rails, odds disclosure.

## Examples of problems to solve (not comprehensive, just reference)
1. Card hierarchy is flat: SEASON PASS, FEATURED, PERMANENT, RARE are all
   rendered as the same pill, so the eye has no entry point.
2. 

## Output contract
- Implement in place. Commit as you go with clear messages.
- Write docs/DECISIONS.md: what you changed, what you rejected, and why.
- Must render correctly at 1280x800, 1024x768, and 390x844.
- Do not read or reference any other branch or worktree.