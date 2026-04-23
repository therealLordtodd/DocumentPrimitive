# A11 — Primitive Adoption & Extraction

**Pass:** Pass A
**Priority:** P7.6
**Focus:** Whether the project draws from the shared primitive/kit library when it should, contributes back to it when it can, and respects the boundary between host code and shared code in both directions.

## Why This Vector Exists

The shared library at `/Users/todd/Programming/Packages/` only becomes "huge, reliable, and filled with awesomeness" if every project does three things:

1. **Uses primitives that already exist** instead of reinventing them locally.
2. **Extracts novel reusable work** so the next project benefits.
3. **Pushes fixes down** into primitives instead of band-aiding around them in host code.

A12 (sibling kit-side vector, if present) handles the inverse: primitives that have grown app-specific concepts. This vector (A11) catches both directions from the *consumer's* perspective.

## Agent Prompt

> You are a code reviewer focused on primitive adoption and extraction. Review [FEATURE] in [PROJECT] ([TECH_STACK]). The shared library lives at `/Users/todd/Programming/Packages/` and contains 100+ primitives and kits. **Before you start, list the directory** so you have a current inventory of what exists. Your job is to enforce the project's Primitives-First Development discipline in three directions: adoption, extraction, and boundary integrity.
>
> Check against these rules:
>
> ### Adoption — "Is this work that an existing primitive already does?"
>
> 1. **Reinvented primitive.** Does any code in scope reimplement functionality that an existing primitive provides? Walk the `Packages/` listing and match names/responsibilities against what the app code is doing. Common offenders: tag chips, badges, toasts, search fields, color pickers, date pickers, drag-and-drop, share sheets, currency formatting, units, validation, progress indicators, context menus, carousels.
> 2. **Wrapper bloat / API mirroring.** Does the app wrap a primitive in an adapter (`MyAppFooAdapter`, `FooHelper`, `FooManager`) that mirrors the primitive's API ≥70% with little added value? Effectively a private fork of the surface — flag it.
> 3. **Reaching around the seams.** Does the app subclass primitive internals, access underscore-prefixed properties, copy primitive source into the app, or otherwise bypass the primitive's intended customization points? Any private-API archaeology is a finding.
> 4. **Stale fork of primitive code.** Is there code in the app that is recognizably copied from a primitive (similar signatures, names, structure) and then modified locally? Worse than a band-aid because the divergence is silent.
> 5. **Conceptual fragmentation across apps.** Even if no single app duplicates, does *this* app invent a concept (a formatter, a chip, a small widget) that *other apps in the workspace* are also inventing independently? Spot-check sibling project directories. If three apps each have their own `RelativeDateText`, the system is duplicating.
> 6. **Performance escape hatch.** Is there code that copies or rewrites a primitive "for performance reasons"? Almost always wrong — the primitive should be optimized. Challenge every perf-justified fork.
> 7. **Theming/style workaround.** Is the app applying overlays, swizzling, or after-the-fact restyling to bend a primitive's appearance, when the primitive should expose the customization point? Flag both the workaround and the missing primitive feature.
>
> ### Extraction — "Should this novel work become a primitive or kit?"
>
> 8. **Primitive-shaped local code.** Is there code in scope that has the *shape* of a primitive — clean inputs/outputs, no app-specific coupling, generally useful — but lives only in this app? Flag it as an extraction candidate even if there's no second consumer yet. The bar is "could another app reasonably use this?", not "does another app use this today?"
> 9. **Composition pattern = kit candidate.** Does the app combine 2+ existing primitives in a recurring useful pattern? That combination itself may belong in the shared library as a *kit* (higher-level than a primitive). Distinguish primitive-extraction findings from kit-extraction findings — different threshold, different home.
> 10. **Tests must migrate with extracted code.** If you flag an extraction candidate, also check: does the app currently have tests covering this code? They must move to the primitive when the extraction happens. Note any extraction PR that lacks corresponding test migration.
>
> ### Boundary Integrity — "Are fixes flowing the right direction?"
>
> 11. **Host-app band-aid for a kit bug.** Is the app working around incorrect primitive behavior with a local patch (a special case, a re-wrap, a "if this case, do it ourselves" branch) instead of fixing the primitive? Every band-aid is a finding. The fix belongs in the primitive — file a kit issue, do not absorb the workaround silently.
> 12. **Workaround comments.** Search for `// HACK`, `// WORKAROUND`, `// FIXME`, `// TODO: remove when X fixes`, `// kit doesn't support`. Each one is a finding — track whether the upstream fix has landed and whether the comment can come out.
> 13. **Version pin defending against a regression.** Is the app pinned to an older kit version, a branch, or a fork to avoid a regression? That's a band-aid that hides a real kit issue. Flag the pin and the underlying problem.
> 14. **Discoverability signal.** If you find the app reinventing a primitive that *does* exist, that is also a finding *against the primitive's discoverability*. Note it. Repeat findings across reviews mean the primitive needs better surfacing — README, naming, listing, or a callout in `Packages/CONVENTIONS/`.
>
> ### When [PROJECT] Itself Is a Primitive or Kit
>
> If you are reviewing a primitive/kit (not an app), invert your focus:
>
> 15. **Reverse-coupling — app concepts leaking in.** Does the primitive import or reference types, vocabulary, or concepts from a specific host app? A primitive that knows about `Vantage`, `DataEstate`, `Noema`, etc., has lost its primitiveness. This is the most insidious failure mode — worse than duplication because it poisons the shared library.
> 16. **Scope creep.** Has the primitive grown responsibilities outside its name's promise? `TagPrimitive` should not contain a date formatter. Flag scope drift.
> 17. **Missing customization seams.** If consumers are reaching around the primitive (per rule 3), the primitive likely needs to expose a new seam. Flag the missing seam, not just the consumer's hack.
>
> ### Output Format
>
> For each finding, clearly distinguish:
> - **Adopt** — app should use existing primitive X (name it)
> - **Extract** — app code should become new primitive/kit Y (suggest name + scope)
> - **Push down** — host band-aid should move into primitive Z as a fix or new feature
> - **Primitive-side** — when reviewing a primitive: it has absorbed app concepts or grown beyond its scope
>
> For each finding: Severity (Critical/High/Medium/Low), File and line number, Description, Suggested fix with code snippet or extraction sketch, Direction (Adopt / Extract / Push down / Primitive-side), Estimated Reality (0–100%). Be thorough but precise — no false positives. The cost of a wrong "extract this" finding is wasted design time; the cost of a missed "you reinvented X" finding is permanent ecosystem fragmentation. Err toward flagging.

## Findings

| Severity | File:Line | Description | Suggested Fix | Direction | Estimated Reality (0–100%) |
|---|---|---|---|---|---|
| — | — | No findings. | — | — | — |

## Notes

-
