---
name: consistency
description: "Keep one feature right everywhere it shows up. Before adding or changing anything that appears on more than one surface — coupon/promo codes, prices, discounts, totals, tax, shipping thresholds, stock, loyalty points, subscriptions, order status — list every surface, make them all read one server calculation, and add one browser spec asserting they agree (plus the edge cases). Use for any cart/checkout/pricing/account change, or when a value 'is right on one page but wrong on another'."
---

# Consistency: One Feature, Every Surface, Same Answer

A coupon that works on the cart page but not in the cart drawer is not a code bug a type
checker sees — it is a *surface* bug. Each surface either recomputes the value itself or was
never told about the new field. Blast-radius tools find callers of a function; they cannot find
a drawer that does its own maths. This skill is three habits that close that gap.

## 1. Map every surface before you change anything

Write the table first — in the plan (Superpowers `writing-plans`), or at the top of the PR.

| Surface | File(s) | Reads value from | Change needed |
|---|---|---|---|
| Cart drawer / mini-cart | | | |
| Cart page | | | |
| Checkout (each step) | | | |
| Order confirmation | | | |
| Account → order history / detail | | | |
| Emails / SMS / push (receipt, abandoned cart) | | | |
| Admin order view / reports / exports | | | |
| API responses + webhooks | | | |

Find them by **data, not just symbols**:
- `graphify query "where is <value> computed and displayed"` (or LSP find-references) for code paths.
- `grep -rn` the field names in every case form (`discount_cents`, `discountCents`, `DISCOUNT`),
  the **UI copy** ("Subtotal", "Discount", "You saved"), and the route/query keys.
- Pass-through files count: a serializer or email template that drops the new field is a surface.

Every empty "reads value from" cell is the bug you would have shipped.

## 2. One source of truth

Every surface reads the value from **one server calculation** (one function, one endpoint or
query key). No surface does its own arithmetic — the client previews at most, the server is
authoritative. When the map shows a surface computing its own total, fix that first: route it
through the shared calculation instead of copying the new rule into it. Money stays in integer
minor units end to end.

## 3. One spec that proves they agree

Add `e2e/consistency-<feature>.spec.ts` (template: `templates/consistency.spec.ts`). It drives
the real app, applies the change, then reads the same values from every surface and asserts
they are **identical**. Give each value the same `data-testid` on every surface
(`summary-subtotal`, `summary-discount`, `summary-total`, …) so one helper reads them all.
Read each surface **inside its own region** (drawer = `getByRole("dialog")`, page = `main`): a
mini-cart is usually in the DOM on every page, so a page-wide read picks up the wrong copy.

Cover the edge cases, not just the happy path. For a coupon: valid · invalid · expired · below
minimum spend · removed again · replaced by another code · stacked (if allowed) · quantity
change after applying · reload / new session (persistence).

`verify.sh` already runs every Playwright spec, so the Stop hook blocks "done" the moment a
later change breaks one surface.

## Pitfalls

- **Fixing the surface you were looking at.** The bug report names one page; the map finds the
  other five.
- **Asserting a hard-coded number per page.** Assert surfaces equal *each other* and the server's
  answer — then a pricing change doesn't rewrite the spec.
- **Mocking the server in this spec.** The point is the real calculation reaching every surface.
- **Forgetting async surfaces.** Emails, webhooks and exports: assert the payload the job would
  send (test the render function), even if the browser can't see it.

## Works with →
- **Superpowers `brainstorming` → `writing-plans`** — the surface map (step 1) is part of the plan.
- **`graphify` / `lsp-plugins`** — find code paths; this skill adds the data/copy search they miss.
- **`browser-verify`** — writes and runs the spec; the compare loop checks each surface looks right.
- **`verify-gate`** — the spec runs inside `verify.sh`; a disagreement blocks the turn.
- **`taste-code`** — one shared calculation beats N copies; no duplicated pricing logic.

## Verification
- Break one surface on purpose (e.g. make the drawer ignore the discount) → the spec fails and
  names that surface.
- Remove the break → `./verify.sh` passes.
