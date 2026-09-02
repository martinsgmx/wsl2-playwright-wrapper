/**
 * Playwright MCP --init-page hook.
 * Auto-fills login form using creds from process.env (loaded via --secrets .secrets.env)
 * and waits for redirect to AUTH_SUCCESS_PATH.
 *
 * Env: AUTH_URL, AUTH_USERNAME, AUTH_PASSWORD, AUTH_SUCCESS_PATH,
 *      AUTH_USER_SELECTOR, AUTH_PASS_SELECTOR, AUTH_SUBMIT_SELECTOR
 */

export default async ({ page }: { page: any }) => {
  const loginUrl = process.env.AUTH_URL || "";
  const successPath = process.env.AUTH_SUCCESS_PATH || "**/dashboard**";
  const username = process.env.AUTH_USERNAME || "";
  const password = process.env.AUTH_PASSWORD || "";
  const userSel =
    process.env.AUTH_USER_SELECTOR ||
    'input[type="email"], input[name="username"], input[name="email"], input[id="username"], input[id="email"]';
  const passSel =
    process.env.AUTH_PASS_SELECTOR || 'input[type="password"], input[name="password"]';
  const submitSel =
    process.env.AUTH_SUBMIT_SELECTOR ||
    'button[type="submit"], button:has-text("Log in"), button:has-text("Sign in"), button:has-text("Login"), input[type="submit"]';

  // Only act when we are on the login page. If AUTH_URL is set, match its pathname;
  // otherwise heuristically detect password field.
  const currentUrl = page.url ? page.url() : "";
  const shouldAct = (() => {
    if (loginUrl) {
      try {
        const want = new URL(loginUrl).pathname;
        return currentUrl.includes(want) || currentUrl.includes("/login");
      } catch {
        return currentUrl.includes("/login");
      }
    }
    // No AUTH_URL configured — don't auto-act; let MCP drive manually
    return false;
  })();

  if (!shouldAct) return;
  if (!username || !password) return;

  try {
    // Wait a tick for page to settle
    await page.waitForTimeout(300).catch(() => {});

    // Check if already past login (already on success path)
    if (successPath && currentUrl.includes(successPath.replace(/\*\*/g, "").replace(/\*/g, ""))) {
      return;
    }

    const hasPassword = await page.locator(passSel).count().catch(() => 0);
    if (!hasPassword) return;

    await page.fill(userSel, username, { timeout: 3000 }).catch(async () => {
      // fallback: try first visible email/username input
      const loc = page.locator(userSel).first();
      await loc.fill(username, { timeout: 3000 }).catch(() => {});
    });

    await page.fill(passSel, password, { timeout: 3000 }).catch(() => {});

    await page.click(submitSel, { timeout: 3000 }).catch(async () => {
      // fallback: press Enter in password field
      await page.locator(passSel).press("Enter").catch(() => {});
    });

    // Wait for redirect to success path (glob) — don't fail session if timeout
    await page.waitForURL(successPath, { timeout: 15000 }).catch(() => {});
  } catch {
    // Never throw — init-page must not break session creation
  }
};
