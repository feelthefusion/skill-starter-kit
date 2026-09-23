// Consistency spec — one feature, every surface, same answer.
// Copy to e2e/consistency-<feature>.spec.ts and fill the SURFACES + applyChange for your app.
// Each surface renders the same data-testids (summary-subtotal / -discount / -total).
import { test, expect, type Page, type Locator } from "@playwright/test";

const FIELDS = ["summary-subtotal", "summary-discount", "summary-total"] as const;
type Snapshot = Record<(typeof FIELDS)[number], string>;

// Every place the values appear. `open` gets the page to that surface; `scope` is the region
// that surface owns — a drawer or header mini-cart is usually in the DOM on every page, so
// reading page-wide would pick up the wrong copy.
const SURFACES: { name: string; open: (page: Page) => Promise<void>; scope: (page: Page) => Locator }[] = [
  {
    name: "cart drawer",
    open: async (p) => { await p.getByRole("button", { name: /cart/i }).first().click(); },
    scope: (p) => p.getByRole("dialog"),
  },
  { name: "cart page", open: async (p) => { await p.goto("/cart"); }, scope: (p) => p.locator("main") },
  { name: "checkout", open: async (p) => { await p.goto("/checkout"); }, scope: (p) => p.locator("main") },
];

async function read(scope: Locator): Promise<Snapshot> {
  const out = {} as Snapshot;
  for (const id of FIELDS) {
    const el = scope.getByTestId(id).first();
    await expect(el, `${id} is missing on this surface`).toBeVisible();
    out[id] = (await el.innerText()).replace(/\s+/g, " ").trim();
  }
  return out;
}

async function snapshotAll(page: Page) {
  const seen: Record<string, Snapshot> = {};
  for (const s of SURFACES) {
    await s.open(page);
    seen[s.name] = await read(s.scope(page));
  }
  return seen;
}

function expectAllEqual(seen: Record<string, Snapshot>) {
  const [first, ...rest] = Object.entries(seen);
  for (const [name, snap] of rest) {
    expect(snap, `${name} disagrees with ${first[0]}`).toEqual(first[1]);
  }
}

test.beforeEach(async ({ page }) => {
  // Arrange a known cart. Replace with your app's add-to-cart flow or a seed endpoint.
  await page.goto("/");
});

// Replace with the change under test (e.g. apply a coupon code).
async function applyChange(page: Page, code: string) {
  await page.goto("/cart");
  await page.getByPlaceholder(/coupon|promo|code/i).fill(code);
  await page.getByRole("button", { name: /apply/i }).click();
}

test("valid code: every surface shows the same discount and total", async ({ page }) => {
  await applyChange(page, "VALID_CODE");
  const seen = await snapshotAll(page);
  expectAllEqual(seen);
  expect(seen["cart page"]["summary-discount"]).not.toMatch(/^(\$?0(\.00)?|—|-)$/);
});

for (const code of ["INVALID_CODE", "EXPIRED_CODE", "BELOW_MINIMUM_CODE"]) {
  test(`${code}: rejected, and no surface shows a discount`, async ({ page }) => {
    const before = await snapshotAll(page);
    await applyChange(page, code);
    const after = await snapshotAll(page);
    expectAllEqual(after);
    expect(after).toEqual(before);
  });
}

test("remove code: every surface returns to the undiscounted totals", async ({ page }) => {
  const before = await snapshotAll(page);
  await applyChange(page, "VALID_CODE");
  await page.goto("/cart");
  await page.getByRole("button", { name: /remove/i }).first().click();
  const after = await snapshotAll(page);
  expectAllEqual(after);
  expect(after).toEqual(before);
});

test("reload keeps the code on every surface", async ({ page }) => {
  await applyChange(page, "VALID_CODE");
  const applied = await snapshotAll(page);
  await page.reload();
  expect(await snapshotAll(page)).toEqual(applied);
});
