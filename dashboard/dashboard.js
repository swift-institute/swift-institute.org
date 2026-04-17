// Swift Institute — Research & Experiments dashboard (prototype)
// Vanilla JS + Fuse.js. Reads research.json and experiments.json manifests.

"use strict";

const CORPORA = {
  research: {
    dataUrl: "research.json",
    entriesKey: "documents",
    title: "Research",
    eyebrow: "Swift Institute",
    lead: "Design rationale and trade-off analysis. When a decision has non-obvious alternatives, the reasoning is recorded as a research document. Each row links to the source markdown on GitHub.",
    githubBase: "https://github.com/swift-institute/Research/blob/main/",
    linkField: "file",
    searchKeys: [
      { name: "displayName", weight: 2 },
      { name: "topic", weight: 1 },
    ],
    columns: [
      { key: "displayName", label: "Document", sortable: true, render: renderDocumentCell },
      { key: "topic", label: "Topic" },
      { key: "tier", label: "Tier", sortable: true, render: renderTierCell, center: true },
      { key: "status", label: "Status", sortable: true, render: renderStatusCell },
    ],
    filters: [
      { key: "status", label: "Status" },
      { key: "tier", label: "Tier", labelFn: (v) => v == null ? "—" : `Tier ${v}` },
    ],
    tableClass: "research",
  },
  experiments: {
    dataUrl: "experiments.json",
    entriesKey: "experiments",
    title: "Experiments",
    eyebrow: "Swift Institute",
    lead: "Runnable Swift packages that verify compiler and runtime behaviour. Each row links to the experiment directory on GitHub — clone and run swift build inside any package to verify the claim.",
    githubBase: "https://github.com/swift-institute/Experiments/tree/main/",
    linkField: "directory",
    searchKeys: [
      { name: "directory", weight: 2 },
      { name: "purpose", weight: 1 },
      { name: "category", weight: 0.5 },
    ],
    columns: [
      { key: "directory", label: "Directory", sortable: true, render: renderDirectoryCell },
      { key: "purpose", label: "Purpose" },
      { key: "date", label: "Date", sortable: true, center: true },
      { key: "toolchain", label: "Toolchain", sortable: true, center: true },
      { key: "status", label: "Status", sortable: true, render: renderStatusCell },
    ],
    filters: [
      { key: "status", label: "Status" },
      { key: "category", label: "Category" },
    ],
    tableClass: "experiments",
  },
};

// ---------- State ----------

let currentCorpus = "research";
const state = {
  research: null, // { entries, activeFilters: {status: Set(), tier: Set()}, search: "", sort: {key, dir} }
  experiments: null,
};

// ---------- Load ----------

async function loadCorpus(key) {
  if (state[key]) return state[key];
  const cfg = CORPORA[key];
  const data = await fetch(cfg.dataUrl).then((r) => r.json());
  const entries = data[cfg.entriesKey].map((e) => ({
    ...e,
    // Normalize tier/status for filtering
    _searchText: (cfg.searchKeys.map((sk) => e[sk.name] || "")).join(" "),
  }));
  state[key] = {
    entries,
    filtered: entries,
    activeFilters: Object.fromEntries(cfg.filters.map((f) => [f.key, new Set()])),
    search: "",
    sort: { key: null, dir: "asc" },
    fuse: new Fuse(entries, {
      keys: cfg.searchKeys,
      threshold: 0.35,
      ignoreLocation: true,
      minMatchCharLength: 2,
    }),
  };
  return state[key];
}

// ---------- Render ----------

function renderStatusCell(entry) {
  const s = entry.status || "";
  const safe = s.replace(/[^A-Z_]/g, "_");
  let html = `<span class="status-chip status-${safe}">${escapeHTML(s)}</span>`;
  if (entry.statusDetail) {
    html += `<span class="status-detail">${escapeHTML(entry.statusDetail)}</span>`;
  }
  if (entry.supersededBy) {
    html += `<span class="status-detail">→ <code>${escapeHTML(entry.supersededBy)}</code></span>`;
  }
  return html;
}

function renderTierCell(entry) {
  if (entry.tier == null) return `<span class="status-detail">—</span>`;
  return `<span class="tier-chip tier-${entry.tier}">Tier ${entry.tier}</span>`;
}

function renderDocumentCell(entry) {
  const cfg = CORPORA.research;
  const url = cfg.githubBase + entry.file;
  return `<div class="title"><a href="${url}" target="_blank" rel="noopener"><code>${escapeHTML(entry.displayName || entry.file)}</code></a></div>`;
}

function renderDirectoryCell(entry) {
  const cfg = CORPORA.experiments;
  const url = cfg.githubBase + entry.directory;
  const cat = entry.category
    ? `<div class="cat-chip" style="margin-top:4px">${escapeHTML(entry.category)}</div>`
    : "";
  return `<div class="title"><a href="${url}" target="_blank" rel="noopener"><code>${escapeHTML(entry.directory)}</code></a></div>${cat}`;
}

function renderRow(entry, cfg) {
  const tr = document.createElement("tr");
  for (const col of cfg.columns) {
    const td = document.createElement("td");
    if (col.center) td.style.textAlign = "center";
    if (col.render) {
      td.innerHTML = col.render(entry);
    } else if (col.key === "topic" || col.key === "purpose") {
      const raw = entry[col.key] || "";
      td.innerHTML = `<div class="topic">${escapeHTML(raw)}</div>`;
      if (raw.length > 240) {
        const toggle = document.createElement("span");
        toggle.className = "expand-toggle";
        toggle.textContent = "Show more";
        toggle.addEventListener("click", () => {
          tr.classList.toggle("expanded");
          toggle.textContent = tr.classList.contains("expanded") ? "Show less" : "Show more";
        });
        td.appendChild(toggle);
      }
    } else {
      td.textContent = entry[col.key] || "";
    }
    tr.appendChild(td);
  }
  return tr;
}

function renderHead(cfg) {
  const st = state[currentCorpus];
  const colgroup = document.createElement("colgroup");
  for (let i = 0; i < cfg.columns.length; i++) colgroup.appendChild(document.createElement("col"));
  const tr = document.createElement("tr");
  for (const col of cfg.columns) {
    const th = document.createElement("th");
    th.textContent = col.label;
    if (col.center) th.style.textAlign = "center";
    if (col.sortable) {
      th.classList.add("sortable");
      const arrow = document.createElement("span");
      arrow.className = "sort-arrow";
      arrow.textContent = "↕";
      if (st.sort.key === col.key) {
        th.classList.add("sorted");
        arrow.textContent = st.sort.dir === "asc" ? "↑" : "↓";
      }
      th.appendChild(arrow);
      th.addEventListener("click", () => {
        if (st.sort.key === col.key) st.sort.dir = st.sort.dir === "asc" ? "desc" : "asc";
        else { st.sort.key = col.key; st.sort.dir = "asc"; }
        applyAndRender();
      });
    }
    tr.appendChild(th);
  }
  const head = document.getElementById("results-head");
  head.innerHTML = "";
  head.appendChild(tr);
  const table = document.getElementById("results");
  table.className = cfg.tableClass;
  // Insert fresh colgroup
  const oldCol = table.querySelector("colgroup");
  if (oldCol) oldCol.remove();
  table.prepend(colgroup);
}

function renderBody(cfg, entries) {
  const body = document.getElementById("results-body");
  body.innerHTML = "";
  for (const e of entries) body.appendChild(renderRow(e, cfg));
  const count = document.getElementById("corpus-count");
  count.textContent = entries.length === state[currentCorpus].entries.length
    ? `${entries.length} entries`
    : `${entries.length} of ${state[currentCorpus].entries.length} entries`;
  const empty = document.getElementById("empty");
  empty.hidden = entries.length > 0;
}

function renderFilters(cfg) {
  const st = state[currentCorpus];
  const statusFilter = cfg.filters.find((f) => f.key === "status");
  const extraFilter = cfg.filters.find((f) => f.key !== "status");

  // Status pills
  const statusValues = uniqueValues(st.entries, "status");
  document.getElementById("status-pills").innerHTML = "";
  for (const v of statusValues) {
    const count = st.entries.filter((e) => e.status === v).length;
    const pill = document.createElement("button");
    pill.className = "pill";
    pill.type = "button";
    if (st.activeFilters.status.has(v)) pill.classList.add("pill-active");
    pill.innerHTML = `${escapeHTML(v)}<span class="pill-count">${count}</span>`;
    pill.addEventListener("click", () => togglePill("status", v));
    document.getElementById("status-pills").appendChild(pill);
  }

  // Extra (tier or category)
  const extraLabel = document.getElementById("extra-label");
  const extraPills = document.getElementById("extra-pills");
  extraPills.innerHTML = "";
  if (extraFilter) {
    extraLabel.textContent = `${extraFilter.label}:`;
    const vals = uniqueValues(st.entries, extraFilter.key);
    for (const v of vals) {
      const count = st.entries.filter((e) => e[extraFilter.key] === v).length;
      const display = extraFilter.labelFn ? extraFilter.labelFn(v) : String(v);
      const pill = document.createElement("button");
      pill.className = "pill";
      pill.type = "button";
      if (st.activeFilters[extraFilter.key].has(v)) pill.classList.add("pill-active");
      pill.innerHTML = `${escapeHTML(display)}<span class="pill-count">${count}</span>`;
      pill.addEventListener("click", () => togglePill(extraFilter.key, v));
      extraPills.appendChild(pill);
    }
    document.getElementById("extra-filters").style.display = "";
  } else {
    document.getElementById("extra-filters").style.display = "none";
  }
}

function togglePill(key, value) {
  const st = state[currentCorpus];
  const set = st.activeFilters[key];
  if (set.has(value)) set.delete(value);
  else set.add(value);
  applyAndRender();
}

function uniqueValues(entries, key) {
  const vals = new Set();
  for (const e of entries) vals.add(e[key]);
  return [...vals].sort((a, b) => {
    if (a == null) return 1;
    if (b == null) return -1;
    return String(a).localeCompare(String(b));
  });
}

// ---------- Apply ----------

function applyAndRender() {
  const cfg = CORPORA[currentCorpus];
  const st = state[currentCorpus];

  // 1. Search
  let entries = st.search
    ? st.fuse.search(st.search).map((r) => r.item)
    : st.entries.slice();

  // 2. Filters (AND across keys, OR within values per key)
  for (const [key, set] of Object.entries(st.activeFilters)) {
    if (set.size > 0) entries = entries.filter((e) => set.has(e[key]));
  }

  // 3. Sort
  if (st.sort.key) {
    const k = st.sort.key;
    const dir = st.sort.dir === "asc" ? 1 : -1;
    entries.sort((a, b) => {
      const av = a[k], bv = b[k];
      if (av == null && bv == null) return 0;
      if (av == null) return 1;
      if (bv == null) return -1;
      if (typeof av === "number" && typeof bv === "number") return (av - bv) * dir;
      return String(av).localeCompare(String(bv)) * dir;
    });
  }

  st.filtered = entries;
  renderBody(cfg, entries);
  renderFilters(cfg);
  renderHead(cfg);
}

// ---------- Corpus switching ----------

async function switchCorpus(key) {
  currentCorpus = key;
  const cfg = CORPORA[key];
  // Tab state
  document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("tab-active", t.dataset.corpus === key));
  // Intro band
  document.getElementById("corpus-title").textContent = cfg.title;
  document.getElementById("corpus-eyebrow").textContent = cfg.eyebrow;
  document.getElementById("corpus-lead").textContent = cfg.lead;
  document.title = `${cfg.title} — Swift Institute`;
  // Nav state
  document.querySelectorAll(".nav-link").forEach((a) => {
    const isActive = (key === "research" && a.getAttribute("href") === "#research") ||
                     (key === "experiments" && a.getAttribute("href") === "#experiments");
    a.classList.toggle("nav-link-active", isActive);
  });
  // Load + render
  await loadCorpus(key);
  // Reset search input value
  document.getElementById("search").value = state[key].search;
  applyAndRender();
}

// ---------- Theme ----------

function currentScheme() {
  return document.body.getAttribute("data-color-scheme") ||
    (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
}

function setScheme(scheme) {
  if (scheme === "auto") {
    document.body.removeAttribute("data-color-scheme");
    localStorage.removeItem("swift-institute-scheme");
  } else {
    document.body.setAttribute("data-color-scheme", scheme);
    localStorage.setItem("swift-institute-scheme", scheme);
  }
  updateThemeIcon();
}

function updateThemeIcon() {
  const icon = document.getElementById("theme-toggle-icon");
  if (!icon) return;
  const scheme = currentScheme();
  // Swap sun <-> moon
  if (scheme === "dark") {
    icon.innerHTML = '<path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/>';
  } else {
    icon.innerHTML = '<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4 7 17M17 7l1.4-1.4"/>';
  }
}

// ---------- Utils ----------

function escapeHTML(s) {
  if (s == null) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

// ---------- Init ----------

document.addEventListener("DOMContentLoaded", async () => {
  // Restore scheme preference before first paint
  const saved = localStorage.getItem("swift-institute-scheme");
  if (saved === "dark" || saved === "light") {
    document.body.setAttribute("data-color-scheme", saved);
  }
  updateThemeIcon();

  // Tab click
  document.querySelectorAll(".tab").forEach((btn) => {
    btn.addEventListener("click", () => switchCorpus(btn.dataset.corpus));
  });
  // Nav click (same behavior)
  document.querySelectorAll(".nav-link").forEach((a) => {
    const href = a.getAttribute("href");
    if (href === "#research" || href === "#experiments") {
      a.addEventListener("click", (e) => {
        e.preventDefault();
        switchCorpus(href.substring(1));
      });
    }
  });
  // Search
  document.getElementById("search").addEventListener("input", (e) => {
    state[currentCorpus].search = e.target.value.trim();
    applyAndRender();
  });
  // Clear
  document.getElementById("clear-filters").addEventListener("click", () => {
    const st = state[currentCorpus];
    for (const set of Object.values(st.activeFilters)) set.clear();
    st.search = "";
    document.getElementById("search").value = "";
    applyAndRender();
  });
  // Theme toggle: cycles light <-> dark
  document.getElementById("theme-toggle").addEventListener("click", () => {
    const next = currentScheme() === "dark" ? "light" : "dark";
    setScheme(next);
  });

  // URL hash routing
  const initial = (location.hash === "#experiments") ? "experiments" : "research";
  await switchCorpus(initial);
});
