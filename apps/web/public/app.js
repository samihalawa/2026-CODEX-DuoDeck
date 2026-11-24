(() => {
  "use strict";

  const CONSENT_KEY = "duodeck.consent.v1";
  const PREVIEW_KEY = "duodeck.preview.v1";
  const THEME_KEY = "duodeck.theme.v1";
  const POSTHOG_HOST = "https://posthog.megawebs.com";
  const POSTHOG_KEY = "phc_D6o2sxKaneoKCAxp8w8oQiD86Bm77AGMboe7DMK5Y8Y6";

  // Theme support (system default, persisted manual toggle, or ?theme=light|dark preview)
  const themeToggle = document.getElementById("themeToggle");
  function setTheme(next, persist = true) {
    if (next === "light" || next === "dark") {
      document.documentElement.setAttribute("data-theme", next);
      if (themeToggle) themeToggle.textContent = next === "dark" ? "Light" : "Dark";
      if (persist) {
        try { localStorage.setItem(THEME_KEY, next); } catch {}
      }
    } else {
      document.documentElement.removeAttribute("data-theme");
      const sysDark = window.matchMedia?.("(prefers-color-scheme: dark)")?.matches;
      if (themeToggle) themeToggle.textContent = sysDark ? "Light" : "Dark";
    }
  }
  try {
    const queryTheme = new URLSearchParams(window.location.search).get("theme");
    const savedTheme = localStorage.getItem(THEME_KEY);
    if (queryTheme === "light" || queryTheme === "dark") setTheme(queryTheme, false);
    else if (savedTheme === "light" || savedTheme === "dark") setTheme(savedTheme, false);
    else setTheme(null, false);
  } catch {
    setTheme(null, false);
  }
  if (themeToggle) {
    themeToggle.addEventListener("click", () => {
      const current = document.documentElement.getAttribute("data-theme")
        || (window.matchMedia?.("(prefers-color-scheme: dark)")?.matches ? "dark" : "light");
      setTheme(current === "dark" ? "light" : "dark", true);
    });
  }

  window.dataLayer = window.dataLayer || [];
  function pushDataLayer() {
    window.dataLayer.push(arguments);
  }
  pushDataLayer("consent", "default", {
    analytics_storage: "denied",
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
  });

  let posthogLoaded = false;
  function loadPostHog() {
    if (posthogLoaded || window.posthog?.__SV) {
      if (window.posthog?.opt_in_capturing) window.posthog.opt_in_capturing();
      return;
    }
    posthogLoaded = true;
    const script = document.createElement("script");
    script.src = POSTHOG_HOST + "/static/array.js";
    script.async = true;
    script.onload = () => {
      if (!window.posthog || typeof window.posthog.init !== "function") return;
      window.posthog.init(POSTHOG_KEY, {
        api_host: POSTHOG_HOST,
        ui_host: POSTHOG_HOST,
        capture_pageview: true,
        capture_pageleave: true,
        capture_exceptions: true,
        autocapture: true,
        person_profiles: "identified_only",
        persistence: "localStorage+cookie",
      });
    };
    document.head.appendChild(script);
  }

  function track(eventName, props) {
    try {
      if (localStorage.getItem(CONSENT_KEY) !== "accepted") return;
      pushDataLayer("event", eventName, props || {});
      if (window.posthog && typeof window.posthog.capture === "function") {
        window.posthog.capture(eventName, props || {});
      }
    } catch {
      // Ignore storage or telemetry restrictions
    }
  }

  window.addEventListener("error", (event) => {
    if (localStorage.getItem(CONSENT_KEY) === "accepted" && window.posthog?.captureException) {
      window.posthog.captureException(event.error || new Error(event.message || "Script error"));
    }
  });
  window.addEventListener("unhandledrejection", (event) => {
    if (localStorage.getItem(CONSENT_KEY) === "accepted" && window.posthog?.captureException) {
      window.posthog.captureException(event.reason instanceof Error ? event.reason : new Error(String(event.reason)));
    }
  });

  // Consent banner controller
  const consentBanner = document.getElementById("consentBanner");
  const acceptBtn = document.getElementById("consentAccept");
  const declineBtn = document.getElementById("consentDecline");
  const manageBtn = document.getElementById("manageConsent");

  function applyConsent(choice) {
    try {
      localStorage.setItem(CONSENT_KEY, choice);
    } catch {
      // Ignore storage denial
    }
    if (consentBanner) consentBanner.hidden = true;
    if (choice === "accepted") {
      pushDataLayer("consent", "update", { analytics_storage: "granted" });
      loadPostHog();
    } else {
      pushDataLayer("consent", "update", { analytics_storage: "denied" });
      if (window.posthog?.opt_out_capturing) window.posthog.opt_out_capturing();
    }
  }

  try {
    const savedConsent = localStorage.getItem(CONSENT_KEY);
    if (savedConsent === "accepted") {
      applyConsent("accepted");
    } else if (!savedConsent && consentBanner) {
      consentBanner.hidden = false;
    }
  } catch {
    if (consentBanner) consentBanner.hidden = false;
  }

  if (acceptBtn) acceptBtn.addEventListener("click", () => applyConsent("accepted"));
  if (declineBtn) declineBtn.addEventListener("click", () => applyConsent("declined"));
  if (manageBtn && consentBanner) {
    manageBtn.addEventListener("click", () => {
      consentBanner.hidden = false;
    });
  }

  // Live Mac Host download check
  const macBtn = document.getElementById("macDownloadBtn");
  const downloadMeta = document.getElementById("downloadMeta");
  if (macBtn) {
    macBtn.addEventListener("click", () => track("duodeck_mac_download_click", { source: "hero_or_card" }));
    fetch("/api/downloads")
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (!data || !data.mac || !downloadMeta) return;
        if (data.mac.available && data.mac.url) {
          macBtn.href = data.mac.url;
          downloadMeta.textContent = "Signed & notarized Universal DMG verified available on GitHub Releases.";
        } else if (data.mac.status === "pending") {
          downloadMeta.textContent = "Mac Host release is uploading — source & release notes remain available on GitHub.";
        } else {
          downloadMeta.textContent = "Latest Universal DMG hosted on GitHub Releases (macOS 14+).";
        }
      })
      .catch(() => {
        if (downloadMeta) downloadMeta.textContent = "Hosted on GitHub Releases (macOS 14+).";
      });
  }

  // Interactive workspace preview
  const sceneSelector = document.getElementById("sceneSelector");
  const layoutSelector = document.getElementById("layoutSelector");
  const presetSelector = document.getElementById("presetSelector");
  const deviceFrame = document.getElementById("deviceFrame");
  const sceneBadge = document.getElementById("sceneBadge");
  const windowTitle = document.getElementById("windowTitle");
  const sceneHeading = document.getElementById("sceneHeading");
  const sceneBody = document.getElementById("sceneBody");
  const macActionLog = document.getElementById("macActionLog");
  const shortcutStrip = document.getElementById("shortcutStrip");
  const trackpadPad = document.getElementById("trackpadPad");
  const macCursor = document.getElementById("macCursor");
  const pointerSpeed = document.getElementById("pointerSpeed");
  const floatKbToggle = document.getElementById("floatKbToggle");
  const floatingKb = document.getElementById("floatingKb");
  const closeFloatKb = document.getElementById("closeFloatKb");
  const backScreenToggle = document.getElementById("backScreenToggle");
  const duoBackPreview = document.getElementById("duoBackPreview");
  const resetPreview = document.getElementById("resetPreview");
  const previewTelemetry = document.getElementById("previewTelemetry");

  if (!sceneSelector || !deviceFrame) return;

  const scenes = {
    notes: {
      badge: "Window · Notes",
      title: "Notes — Release Checklist.md",
      heading: "Single-window capture keeps everything else private",
      body: "Only the Mac window you pick streams to your phone. Drag across the trackpad below to steer the Mac pointer or open Floating Keyboard to send chords.",
    },
    code: {
      badge: "Window · Xcode",
      title: "DuoDeck.xcodeproj — FloatingKeyboard.swift",
      heading: "Keep builds running while navigating files from the couch",
      body: "Trigger Cmd+R, Cmd+Shift+O, or arrow keys with Esc, Tab, and Control modifiers always one tap away.",
    },
    browser: {
      badge: "Window · Safari",
      title: "Safari — Documentation & Staging",
      heading: "Two-finger scroll and link clicks without full desktop clutter",
      body: "Switch between direct Touch mode and invisible relative Trackpad mode anytime from View › Tracking mode.",
    },
    presenting: {
      badge: "Desktop · Keynote",
      title: "Keynote — Product Deck.key",
      heading: "Run slides from your palm or the iPhone Duo outer screen",
      body: "Use the Presenting shortcut preset and Back screen mirror so notes stay on the Mac while slides advance cleanly.",
    },
  };

  const presets = {
    editing: ["Undo (Cmd+Z)", "Redo (Shift+Cmd+Z)", "Copy (Cmd+C)", "Paste (Cmd+V)", "Find (Cmd+F)", "Spotlight"],
    browsing: ["Back (Cmd+[)", "Forward (Cmd+])", "New Tab (Cmd+T)", "Reload (Cmd+R)", "Find (Cmd+F)"],
    presenting: ["Prev Slide", "Next Slide", "Play Deck", "Black Screen (B)", "Exit (Esc)"],
    code: ["Open Quickly (Shift+Cmd+O)", "Run (Cmd+R)", "Stop (Cmd+.)", "Comment (Cmd+/)", "Build (Cmd+B)"],
  };

  const defaults = {
    scene: "notes",
    layout: "split",
    preset: "editing",
    speed: 1.2,
    floatingKb: false,
    backScreen: false,
  };

  let state = { ...defaults };
  try {
    const raw = localStorage.getItem(PREVIEW_KEY);
    if (raw) state = { ...defaults, ...JSON.parse(raw) };
  } catch {
    state = { ...defaults };
  }

  let cursorX = 48;
  let cursorY = 52;
  let lastPointer = null;
  const stickyMods = new Set();

  function saveState() {
    try {
      localStorage.setItem(PREVIEW_KEY, JSON.stringify(state));
    } catch {
      // Ignore storage denial
    }
  }

  function setPressedGroup(container, attr, activeVal) {
    if (!container) return;
    container.querySelectorAll("button").forEach((btn) => {
      btn.setAttribute("aria-pressed", String(btn.dataset[attr] === activeVal));
    });
  }

  function renderShortcuts() {
    if (!shortcutStrip) return;
    const list = presets[state.preset] || presets.editing;
    shortcutStrip.innerHTML = "";
    list.forEach((label) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "shortcut-chip";
      btn.textContent = label;
      btn.addEventListener("click", () => {
        if (macActionLog) macActionLog.textContent = `Sent Mac shortcut: ${label}`;
        track("duodeck_preview_interact", { kind: "shortcut", value: label });
      });
      shortcutStrip.appendChild(btn);
    });
  }

  function render() {
    const sc = scenes[state.scene] || scenes.notes;
    if (sceneBadge) sceneBadge.textContent = sc.badge;
    if (windowTitle) windowTitle.textContent = sc.title;
    if (sceneHeading) sceneHeading.textContent = sc.heading;
    if (sceneBody) sceneBody.textContent = sc.body;

    deviceFrame.classList.remove("is-split", "is-trackpad", "is-desktop");
    deviceFrame.classList.add(`is-${state.layout}`);

    setPressedGroup(sceneSelector, "scene", state.scene);
    setPressedGroup(layoutSelector, "layout", state.layout);
    setPressedGroup(presetSelector, "preset", state.preset);

    if (pointerSpeed) pointerSpeed.value = String(state.speed);
    if (floatKbToggle) floatKbToggle.setAttribute("aria-pressed", String(Boolean(state.floatingKb)));
    if (floatingKb) floatingKb.hidden = !state.floatingKb;
    if (backScreenToggle) backScreenToggle.setAttribute("aria-pressed", String(Boolean(state.backScreen)));
    if (duoBackPreview) duoBackPreview.hidden = !state.backScreen;

    renderShortcuts();
    if (previewTelemetry) {
      const kbLabel = state.floatingKb ? " · Floating Keyboard open" : "";
      const backLabel = state.backScreen ? " · Back screen active" : "";
      previewTelemetry.textContent = `Scene: ${sc.badge} · Layout: ${state.layout} · Speed ${Number(state.speed).toFixed(1)}x${kbLabel}${backLabel}`;
    }
    saveState();
  }

  sceneSelector.addEventListener("click", (event) => {
    const btn = event.target.closest("button[data-scene]");
    if (!btn) return;
    state.scene = btn.dataset.scene;
    render();
  });

  if (layoutSelector) {
    layoutSelector.addEventListener("click", (event) => {
      const btn = event.target.closest("button[data-layout]");
      if (!btn) return;
      state.layout = btn.dataset.layout;
      render();
    });
  }

  if (presetSelector) {
    presetSelector.addEventListener("click", (event) => {
      const btn = event.target.closest("button[data-preset]");
      if (!btn) return;
      state.preset = btn.dataset.preset;
      render();
    });
  }

  if (pointerSpeed) {
    pointerSpeed.addEventListener("input", () => {
      state.speed = Number(pointerSpeed.value) || 1.2;
      render();
    });
  }

  if (floatKbToggle) {
    floatKbToggle.addEventListener("click", () => {
      state.floatingKb = !state.floatingKb;
      render();
    });
  }
  if (closeFloatKb) {
    closeFloatKb.addEventListener("click", () => {
      state.floatingKb = false;
      render();
    });
  }

  if (floatingKb) {
    floatingKb.addEventListener("click", (event) => {
      const btn = event.target.closest("button[data-key]");
      if (!btn) return;
      const key = btn.dataset.key;
      if (["Ctrl", "Opt", "Cmd", "Shift"].includes(key)) {
        if (stickyMods.has(key)) {
          stickyMods.delete(key);
          btn.setAttribute("aria-pressed", "false");
        } else {
          stickyMods.add(key);
          btn.setAttribute("aria-pressed", "true");
        }
        if (macActionLog) {
          macActionLog.textContent = stickyMods.size
            ? `Latched modifiers: ${Array.from(stickyMods).join(" + ")}`
            : "Modifiers cleared";
        }
      } else {
        const prefix = stickyMods.size ? `${Array.from(stickyMods).join("+")}+` : "";
        if (macActionLog) macActionLog.textContent = `Floating Keyboard sent: ${prefix}${key}`;
        stickyMods.clear();
        floatingKb.querySelectorAll("button[data-key]").forEach((k) => k.setAttribute("aria-pressed", "false"));
      }
    });
  }

  if (backScreenToggle) {
    backScreenToggle.addEventListener("click", () => {
      state.backScreen = !state.backScreen;
      render();
    });
  }

  if (trackpadPad && macCursor) {
    trackpadPad.addEventListener("pointerenter", (event) => {
      lastPointer = { x: event.clientX, y: event.clientY };
    });
    trackpadPad.addEventListener("pointerleave", () => {
      lastPointer = null;
    });
    trackpadPad.addEventListener("pointermove", (event) => {
      if (!lastPointer) {
        lastPointer = { x: event.clientX, y: event.clientY };
        return;
      }
      const dx = (event.clientX - lastPointer.x) * state.speed * 0.28;
      const dy = (event.clientY - lastPointer.y) * state.speed * 0.42;
      lastPointer = { x: event.clientX, y: event.clientY };
      cursorX = Math.max(6, Math.min(92, cursorX + dx));
      cursorY = Math.max(10, Math.min(86, cursorY + dy));
      macCursor.style.left = `${cursorX.toFixed(1)}%`;
      macCursor.style.top = `${cursorY.toFixed(1)}%`;
    });
    trackpadPad.addEventListener("pointerdown", () => {
      if (macActionLog) {
        macActionLog.textContent = `Primary click sent at (${Math.round(cursorX)}%, ${Math.round(cursorY)}%)`;
      }
    });
  }

  if (resetPreview) {
    resetPreview.addEventListener("click", () => {
      state = { ...defaults };
      cursorX = 48;
      cursorY = 52;
      if (macCursor) {
        macCursor.style.left = "48%";
        macCursor.style.top = "52%";
      }
      if (macActionLog) macActionLog.textContent = "Preview reset to defaults";
      stickyMods.clear();
      render();
    });
  }

  render();
})();
