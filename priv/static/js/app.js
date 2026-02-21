/**
 * IOTA Service — Frontend JavaScript
 *
 * Auth flow with RBAC:
 *   - On login, JWT and role are stored in sessionStorage.
 *   - admin role → redirected to / (dashboard), can navigate to /identity.
 *   - user  role → redirected to /portal (DID upload page).
 *   - Nav links are rendered dynamically per role.
 *   - When login_required is off, auth checks are skipped.
 */

// ---------------------------------------------------------------------------
// Session helpers
// ---------------------------------------------------------------------------

function getToken() {
  return sessionStorage.getItem("iota_token");
}
function setToken(t) {
  sessionStorage.setItem("iota_token", t);
}
function getRole() {
  return sessionStorage.getItem("iota_role");
}
function setRole(r) {
  sessionStorage.setItem("iota_role", r);
}
function clearSession() {
  sessionStorage.removeItem("iota_token");
  sessionStorage.removeItem("iota_role");
}
function isLoggedIn() {
  return !!getToken();
}

/** Read the server-injected flag from <body data-login-required="true|false"> */
function isLoginRequired() {
  return document.body.dataset.loginRequired === "true";
}

/**
 * If login is required and the user has no token, redirect to /login.
 * Returns true when the redirect happens (caller should bail out).
 */
function requireAuth() {
  if (isLoginRequired() && !isLoggedIn()) {
    window.location.href = "/login";
    return true;
  }
  return false;
}

/**
 * Require a specific role. Redirects away if the wrong role.
 * Returns true when a redirect happens.
 */
function requireRole(role) {
  if (!isLoginRequired()) return false;
  if (requireAuth()) return true;
  if (getRole() !== role) {
    // Wrong role — send to correct home
    window.location.href = getRole() === "admin" ? "/" : "/portal";
    return true;
  }
  return false;
}

/** Return the landing page for the current role. */
function roleLandingPage() {
  return getRole() === "user" ? "/portal" : "/";
}

// ---------------------------------------------------------------------------
// API helper
// ---------------------------------------------------------------------------

async function api(method, path, body = null) {
  const headers = { "Content-Type": "application/json" };
  const token = getToken();
  if (token) headers["Authorization"] = `Bearer ${token}`;
  const opts = { method, headers };
  if (body) opts.body = JSON.stringify(body);

  const res = await fetch(`/api${path}`, opts);
  const data = await res.json();

  // auto-logout on 401
  if (res.status === 401) {
    clearToken();
  }
  return { status: res.status, data };
}

// ---------------------------------------------------------------------------
// UI helpers
// ---------------------------------------------------------------------------

function show(id, data, isError = false) {
  const el = document.getElementById(id);
  if (!el) return;
  el.style.display = "block";
  el.textContent =
    typeof data === "string" ? data : JSON.stringify(data, null, 2);
  el.style.borderColor = isError ? "#a04048" : "rgb(5, 204, 147)";
}

function setLoading(btnId, loading) {
  const btn = document.getElementById(btnId);
  if (btn) btn.setAttribute("aria-busy", loading);
}

function showNotice(id, message, type = "success") {
  const el = document.getElementById(id);
  if (!el) return;
  el.style.display = "block";
  el.className = `notice ${type}`;
  el.textContent = message;
}

// ---------------------------------------------------------------------------
// Nav: role-aware links + auth state
// ---------------------------------------------------------------------------

function updateNav() {
  const navLinks = document.getElementById("nav-links");
  if (!navLinks) return; // nav hidden on login page

  const authItem = document.getElementById("nav-auth-item");
  const role = getRole();

  // Build role-specific nav links (inserted before auth item)
  if (role === "admin" || !isLoginRequired()) {
    insertNavLink(navLinks, authItem, "/", "Dashboard", "dashboard");
    insertNavLink(navLinks, authItem, "/identity", "Identity", "identity");
  } else if (role === "user") {
    insertNavLink(navLinks, authItem, "/portal", "Portal", "portal");
  }

  // Auth item
  if (!isLoginRequired()) {
    authItem.style.display = "none";
    return;
  }

  if (isLoggedIn()) {
    authItem.innerHTML = '<a href="#" id="nav-logout">Logout</a>';
    document.getElementById("nav-logout").addEventListener("click", (e) => {
      e.preventDefault();
      clearSession();
      window.location.href = "/login";
    });
  } else {
    authItem.innerHTML = '<a href="/login">Login</a>';
  }
}

/** Insert a <li><a> before a reference node. Highlights based on current path. */
function insertNavLink(parent, before, href, label, key) {
  const li = document.createElement("li");
  const a = document.createElement("a");
  a.href = href;
  a.textContent = label;
  // Highlight active link
  const current = window.location.pathname;
  if (current === href || (href !== "/" && current.startsWith(href))) {
    a.className = "contrast";
  }
  li.appendChild(a);
  parent.insertBefore(li, before);
}

// ---------------------------------------------------------------------------
// Login page
// ---------------------------------------------------------------------------

function initLogin() {
  const form = document.getElementById("login-form");
  if (!form) return;

  // Already logged in? Skip to role-appropriate page
  if (isLoggedIn()) {
    window.location.href = roleLandingPage();
    return;
  }

  form.addEventListener("submit", async () => {
    setLoading("btn-login", true);
    const email = document.getElementById("login-email").value;
    const password = document.getElementById("login-password").value;

    try {
      const res = await api("POST", "/auth/login", { email, password });
      if (res.status === 200) {
        setToken(res.data.token);
        setRole(res.data.user.role || "user");
        showNotice(
          "login-status",
          `Authenticated as ${res.data.user.email} (${res.data.user.role})`,
          "success"
        );
        const dest = res.data.user.role === "user" ? "/portal" : "/";
        setTimeout(() => (window.location.href = dest), 600);
      } else {
        showNotice(
          "login-status",
          res.data.message || "Login failed",
          "error"
        );
      }
    } catch (err) {
      showNotice("login-status", `Error: ${err.message}`, "error");
    } finally {
      setLoading("btn-login", false);
    }
  });
}

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

function initDashboard() {
  const btn = document.getElementById("btn-quick-did");
  if (!btn) return;

  // Admin-only page
  if (requireRole("admin")) return;

  btn.addEventListener("click", async () => {
    setLoading("btn-quick-did", true);
    try {
      const res = await api("POST", "/dids", {
        network: "iota",
        publish: false,
      });
      show("quick-did-result", res.data, res.status >= 400);
    } catch (err) {
      show("quick-did-result", `Error: ${err.message}`, true);
    } finally {
      setLoading("btn-quick-did", false);
    }
  });
}

// ---------------------------------------------------------------------------
// Identity page
// ---------------------------------------------------------------------------

function initIdentity() {
  const createForm = document.getElementById("create-did-form");
  if (!createForm) return;

  // Admin-only page
  if (requireRole("admin")) return;

  // --- Publish toggle → show/hide ledger params vs local-only section ------
  const publishSwitch = document.getElementById("did-publish");
  const ledgerParams = document.getElementById("ledger-params");
  const localSection = document.getElementById("local-only-section");
  const submitBtn = document.getElementById("btn-create-did");

  function syncPublishUI() {
    const on = publishSwitch.checked;
    ledgerParams.style.display = on ? "block" : "none";
    localSection.style.display = on ? "none" : "block";
    submitBtn.textContent = on ? "Publish DID" : "Generate Local DID";

    // Toggle required attributes
    document.getElementById("did-secret-key").required = on;
    document.getElementById("did-node-url").required = on;
  }
  publishSwitch.addEventListener("change", syncPublishUI);
  syncPublishUI(); // run once on load

  // --- Create DID ----------------------------------------------------------
  createForm.addEventListener("submit", async () => {
    setLoading("btn-create-did", true);
    const publish = publishSwitch.checked;

    let body;
    if (publish) {
      body = {
        publish: true,
        secret_key: document.getElementById("did-secret-key").value,
        node_url: document.getElementById("did-node-url").value,
        identity_pkg_id:
          document.getElementById("did-identity-pkg-id").value || undefined,
      };
    } else {
      body = {
        publish: false,
        network: document.getElementById("did-network").value,
      };
    }

    try {
      const res = await api("POST", "/dids", body);
      show("create-did-result", res.data, res.status >= 400);
      if (res.status === 201 && res.data.did) {
        const resolveInput = document.getElementById("resolve-did-input");
        const revokeInput = document.getElementById("revoke-did-input");
        if (resolveInput) resolveInput.value = res.data.did;
        if (revokeInput) revokeInput.value = res.data.did;
      }
    } catch (err) {
      show("create-did-result", `Error: ${err.message}`, true);
    } finally {
      setLoading("btn-create-did", false);
    }
  });

  // --- Resolve DID ---------------------------------------------------------
  document
    .getElementById("resolve-did-form")
    .addEventListener("submit", async () => {
      setLoading("btn-resolve-did", true);
      const did = document.getElementById("resolve-did-input").value;
      const nodeUrl = document.getElementById("resolve-node-url").value;
      const pkgId = document.getElementById("resolve-identity-pkg-id").value;

      try {
        const params = new URLSearchParams();
        if (nodeUrl) params.set("node_url", nodeUrl);
        if (pkgId) params.set("identity_pkg_id", pkgId);
        const qs = params.toString();

        const encodedDid = encodeURIComponent(did);
        const url = `/dids/${encodedDid}` + (qs ? `?${qs}` : "");
        const res = await api("GET", url);
        show("resolve-did-result", res.data, res.status >= 400);
      } catch (err) {
        show("resolve-did-result", `Error: ${err.message}`, true);
      } finally {
        setLoading("btn-resolve-did", false);
      }
    });

  // --- Deactivate DID ------------------------------------------------------
  document
    .getElementById("revoke-did-form")
    .addEventListener("submit", async () => {
      setLoading("btn-revoke-did", true);
      const did = document.getElementById("revoke-did-input").value;
      const secretKey = document.getElementById("revoke-secret-key").value;
      const nodeUrl =
        document.getElementById("revoke-node-url").value || undefined;
      const pkgId =
        document.getElementById("revoke-identity-pkg-id").value || undefined;

      try {
        const encodedDid = encodeURIComponent(did);
        const res = await api("POST", `/dids/${encodedDid}/revoke`, {
          secret_key: secretKey,
          node_url: nodeUrl,
          identity_pkg_id: pkgId,
        });
        show("revoke-did-result", res.data, res.status >= 400);
      } catch (err) {
        show("revoke-did-result", `Error: ${err.message}`, true);
      } finally {
        setLoading("btn-revoke-did", false);
      }
    });
}

// ---------------------------------------------------------------------------
// Portal page (user role)
// ---------------------------------------------------------------------------

function initPortal() {
  const form = document.getElementById("upload-did-form");
  if (!form) return;

  // User-only page
  if (requireRole("user")) return;

  form.addEventListener("submit", async () => {
    setLoading("btn-upload-did", true);
    // Hide previous results
    const statusEl = document.getElementById("upload-did-status");
    const resultEl = document.getElementById("upload-did-result");
    if (statusEl) statusEl.style.display = "none";
    if (resultEl) resultEl.style.display = "none";

    const did = document.getElementById("upload-did-input").value.trim();
    const nodeUrl = document.getElementById("portal-node-url").value.trim();
    const pkgId = document.getElementById("portal-identity-pkg-id").value.trim();

    try {
      const body = { did };
      if (nodeUrl) body.node_url = nodeUrl;
      if (pkgId) body.identity_pkg_id = pkgId;
      const res = await api("POST", "/dids/validate", body);
      if (res.status === 200 && res.data.valid) {
        showNotice("upload-did-status", "DID is valid. Access granted.", "success");
        show("upload-did-result", res.data, false);
      } else {
        showNotice(
          "upload-did-status",
          res.data.message || "Invalid DID",
          "error"
        );
        show("upload-did-result", res.data, true);
      }
    } catch (err) {
      showNotice("upload-did-status", `Error: ${err.message}`, "error");
    } finally {
      setLoading("btn-upload-did", false);
    }
  });
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

document.addEventListener("DOMContentLoaded", () => {
  updateNav();
  initLogin();
  initDashboard();
  initIdentity();
  initPortal();
});
