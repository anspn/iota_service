/**
 * IOTA Service — Frontend JavaScript
 *
 * Auth flow: login page stores JWT in sessionStorage → protected pages
 * read it back. Identity page sends client-supplied ledger params.
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
function clearToken() {
  sessionStorage.removeItem("iota_token");
}
function isLoggedIn() {
  return !!getToken();
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
// Nav: auth state — show Login or Logout in nav
// ---------------------------------------------------------------------------

function updateNav() {
  const authItem = document.getElementById("nav-auth-item");
  if (!authItem) return;

  if (isLoggedIn()) {
    authItem.innerHTML = '<a href="#" id="nav-logout">Logout</a>';
    document.getElementById("nav-logout").addEventListener("click", (e) => {
      e.preventDefault();
      clearToken();
      window.location.href = "/login";
    });
  } else {
    authItem.innerHTML = '<a href="/login">Login</a>';
  }

  // Auth-gated links: redirect to /login if not logged in
  document.querySelectorAll("[data-auth-link]").forEach((link) => {
    link.addEventListener("click", (e) => {
      if (!isLoggedIn()) {
        e.preventDefault();
        window.location.href = "/login";
      }
    });
  });
}

// ---------------------------------------------------------------------------
// Login page
// ---------------------------------------------------------------------------

function initLogin() {
  const form = document.getElementById("login-form");
  if (!form) return;

  // Already logged in? Go to identity page
  if (isLoggedIn()) {
    window.location.href = "/identity";
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
        showNotice("login-status", `Authenticated as ${res.data.user.email}`, "success");
        // Small delay so the user can see the success message, then redirect
        setTimeout(() => (window.location.href = "/identity"), 600);
      } else {
        showNotice("login-status", res.data.message || "Login failed", "error");
      }
    } catch (err) {
      showNotice("login-status", `Error: ${err.message}`, "error");
    } finally {
      setLoading("btn-login", false);
    }
  });
}

// ---------------------------------------------------------------------------
// Dashboard — Quick DID generation
// ---------------------------------------------------------------------------

function initDashboard() {
  const btn = document.getElementById("btn-quick-did");
  if (!btn) return;

  btn.addEventListener("click", async () => {
    if (!isLoggedIn()) {
      window.location.href = "/login";
      return;
    }
    setLoading("btn-quick-did", true);
    try {
      const res = await api("POST", "/dids", { network: "iota", publish: false });
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

  // Gate: must be logged in
  if (!isLoggedIn()) {
    window.location.href = "/login";
    return;
  }

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
        // Auto-fill resolve/revoke inputs with the new DID
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
        let qs = "";
        const params = new URLSearchParams();
        if (nodeUrl) params.set("node_url", nodeUrl);
        if (pkgId) params.set("identity_pkg_id", pkgId);
        qs = params.toString();

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

  // --- Revoke DID ----------------------------------------------------------
  document
    .getElementById("revoke-did-form")
    .addEventListener("submit", async () => {
      setLoading("btn-revoke-did", true);
      const did = document.getElementById("revoke-did-input").value;
      const reason =
        document.getElementById("revoke-reason").value || undefined;

      try {
        const encodedDid = encodeURIComponent(did);
        const res = await api("POST", `/dids/${encodedDid}/revoke`, {
          reason,
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
// Init
// ---------------------------------------------------------------------------

document.addEventListener("DOMContentLoaded", () => {
  updateNav();
  initLogin();
  initDashboard();
  initIdentity();
});
