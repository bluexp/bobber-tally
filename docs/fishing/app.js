const base = new URL(".", import.meta.url);
const zh = typeof document !== "undefined" && document.documentElement.lang === "zh-CN";
const t = (cn, en) => zh ? cn : en;
const el = (id) => document.getElementById(id);
const make = (tag, text) => Object.assign(document.createElement(tag), { textContent: text ?? "" });
const number = new Intl.NumberFormat(zh ? "zh-CN" : "en");
const regions = ["CN", "US", "EU", "KR", "TW", "UNKNOWN"];
const regionName = (region) => ({
  CN: t("中国大陆", "China"), US: t("美洲", "Americas"), EU: t("欧洲", "Europe"),
  KR: t("韩国", "Korea"), TW: t("台湾", "Taiwan"), UNKNOWN: t("地区未知", "Unknown region")
})[region];
const lureName = (lure) => ({
  active: t("鱼饵生效", "Lure active"), none: t("无鱼饵", "No lure"), unknown: t("鱼饵未知", "Lure unknown")
})[lure];

export function parseRecords(raw, maxRows = 20) {
  const input = raw.trim();
  if (!input.startsWith("WFDB1:")) throw new Error("format");
  const rows = input.slice(6).split(";");
  if (rows.length > maxRows || rows.some((row) => row.length > 70)) throw new Error("size");
  const records = rows.map((row) => {
    const fields = row.split(",");
    if (fields.length !== 7 || [0, 1, 2, 4, 6].some((i) => !/^\d{1,8}$/.test(fields[i]))) throw new Error("format");
    const [item, map, day, region, build, lure, count] = fields;
    if (+item < 1 || +item > 9999999 || +map > 999999 || +day < 20000 || +day > 50000 ||
        +build > 999999 || +count < 1 || +count > 999999 || !regions.includes(region) ||
        !["active", "none", "unknown"].includes(lure)) throw new Error("format");
    return { item: +item, map: +map, day: +day, region, build: +build, lure, count: +count };
  });
  if (new Set(records.map((r) => [r.item, r.map, r.day, r.region, r.build, r.lure, r.count].join(","))).size !== records.length) {
    throw new Error("duplicate");
  }
  return records;
}

async function dataFile(name) {
  const response = await fetch(new URL(name, base));
  if (!response.ok) throw new Error(name);
  return response.json();
}

async function start() {
  const catalog = await dataFile("catalog.json");
  const reviews = await dataFile("observations.json").catch(() => null);
  const { fish, zones, items, featuredZones, featuredFish, recipes } = catalog;
  const byID = new Map(fish.map((row) => [row.id, row]));
  const name = (entry) => entry?.[zh ? "zh" : "en"] ?? "";
  const itemName = (id) => name(items[id]) || "#" + id;
  const mapName = (id) => name(Object.values(zones).find((zone) => zone.map === id)) || (id ? "#" + id : t("地图未知", "Unknown map"));
  const subzones = new Set([297, 1112, 1222, 1227, 1977, 3140]);
  const fmtDate = (day) => new Date(day * 86400000).toISOString().slice(0, 10);
  const option = (value, label) => new Option(label, value);
  const reviewed = Array.isArray(reviews);

  for (const id of [...featuredZones, ...Object.keys(zones).map(Number).filter((id) => !featuredZones.includes(id))
    .sort((a, b) => name(zones[a]).localeCompare(name(zones[b]), zh ? "zh-CN" : "en"))]) {
    el("zone").add(option(id, name(zones[id])));
  }
  for (const region of regions) el("region").add(option(region, regionName(region)));
  for (const recipe of recipes) el("recipe").add(option(recipe.id, itemName(recipe.id)));
  el("catalog-build").textContent = t("资料版本 ", "Catalog build ") + catalog.build;

  function appendRecords(table, records, attributed) {
    for (const record of records) {
      const row = table.insertRow();
      const date = fmtDate(record.day);
      const values = [itemName(record.item), mapName(record.map), regionName(record.region), date,
        record.build || t("未知", "Unknown"), lureName(record.lure), number.format(record.count)];
      if (attributed) values.push(record.credit || t("匿名", "Anonymous"));
      for (const value of values) row.insertCell().textContent = value;
    }
  }

  function renderRecipes() {
    const recipe = recipes.find((row) => row.id === Number(el("recipe").value));
    const wanted = el("servings").valueAsNumber;
    const output = el("ingredients");
    output.replaceChildren();
    if (!recipe || !Number.isInteger(wanted) || wanted < 1 || wanted > 9999) {
      el("recipe-result").textContent = t("请输入 1 到 9999 份。", "Enter 1 to 9,999 servings.");
      return;
    }
    const batches = Math.ceil(wanted / recipe.quantity);
    el("recipe-result").textContent = t(`制作 ${batches} 次，共 ${batches * recipe.quantity} 份`, `${batches} crafts, ${batches * recipe.quantity} servings`);
    for (const [id, perCraft] of recipe.materials) {
      const amount = batches * perCraft;
      const row = make("li");
      const title = make("strong", itemName(id));
      const already = document.createElement("input");
      Object.assign(already, { type: "number", min: 0, max: 99999, step: 1, value: 0 });
      const label = make("label", t("已有", "On hand"));
      label.append(already);
      already.setAttribute("aria-label", itemName(id) + " " + t("已有数量", "on hand"));
      const result = make("span");
      const update = () => {
        const missing = Math.max(0, amount - (already.validity.valid ? already.valueAsNumber || 0 : 0));
        result.textContent = t(`共需 ${amount} · 还差 ${missing}`, `${amount} needed · ${missing} remaining`);
      };
      already.addEventListener("input", update);
      row.append(title, label, result);
      if (byID.has(id)) {
        const show = make("button", t("查钓点", "Find waters"));
        show.type = "button";
        show.addEventListener("click", () => filterByFish(id));
        row.append(show);
      }
      output.append(row);
      update();
    }
  }

  function filterByFish(id) {
    el("query").value = String(id);
    el("zone").value = "";
    renderCatalog();
    el("lookup").scrollIntoView({ block: "start" });
  }

  function renderCatalog() {
    const query = el("query").value.trim().toLocaleLowerCase();
    const zoneID = Number(el("zone").value);
    const region = el("region").value;
    const observations = reviewed ? reviews.filter((row) => !region || row.region === region) : [];
    const matchingRecords = (id) => observations.filter((row) =>
      row.item === id && (!zoneID || (!subzones.has(zoneID) && row.map !== 0 && row.map === zones[zoneID]?.map)));
    const output = el("fish-list");
    output.replaceChildren();
    const ordered = !query && !zoneID && !region ? featuredFish.map((id) => byID.get(id)) : fish;
    const shown = ordered.filter((row) => {
      if (zoneID && !row.zones?.includes(zoneID) && matchingRecords(row.id).length === 0) return false;
      return !query || (/^\d+$/.test(query) ? String(row.id) === query :
        [items[row.id].zh, items[row.id].en].some((value) => value.toLocaleLowerCase().includes(query)));
    });
    el("result-count").textContent = t(`${shown.length} 种鱼`, `${shown.length} fish`);
    for (const row of shown) {
      const card = make("article");
      card.className = "fish-entry";
      const header = make("div");
      header.append(make("h3", itemName(row.id)), make("span", "#" + row.id));
      card.append(header);
      const regional = matchingRecords(row.id);
      const provenance = row.reported ? t("无限服玩家报告", "Forever player report") : t("经典旧世参考", "Classic Era reference");
      const labels = (row.zones ?? []).map((id) => name(zones[id]));
      card.append(make("p", labels.length ? provenance + " · " + labels.join(zh ? "、" : ", ") :
        t("钓点待确认", "Waters unconfirmed")));
      if (row.reported && row.id === 251524) card.append(make("p", t("玩家报告来自赤脊山奇想鳍鱼群。", "Reported from Whimsyfin schools in Redridge.")));
      card.append(make("p", !reviewed ? t("实测库暂不可用", "Observations unavailable") : regional.length ?
        t(`已收录 ${regional.length} 组实测`, `${regional.length} reviewed observation groups`) :
        t("暂无所选地区的已收录实测", "No reviewed observations for this filter")));
      if (regional.length) {
        const table = document.createElement("table");
        const headings = table.createTHead().insertRow();
        for (const title of t(["鱼类", "地图", "地区", "日期", "构建", "鱼饵", "数量", "贡献者"], ["Fish", "Map", "Region", "Date", "Build", "Lure", "Count", "Contributor"])) {
          const cell = make("th", title);
          cell.scope = "col";
          headings.append(cell);
        }
        appendRecords(table.createTBody(), regional, true);
        const scroll = make("div");
        scroll.className = "table-scroll";
        scroll.append(table);
        card.append(scroll);
      }
      if (zh && row.uses?.length) card.append(make("p", "其他用途 · " + row.uses.join("、")));
      const related = recipes.filter((recipe) => recipe.materials.some(([id]) => row.id === id));
      for (const recipe of related) {
        const button = make("button", itemName(recipe.id) + " →");
        button.type = "button";
        button.addEventListener("click", () => {
          el("recipe").value = recipe.id;
          renderRecipes();
          el("cooking").scrollIntoView({ block: "start" });
        });
        card.append(button);
      }
      output.append(card);
    }
    if (!shown.length) output.append(make("p", t("没有匹配的鱼。可改用鱼名或物品编号搜索。", "No matches. Try a fish name or item ID.")));
  }

  for (const id of ["query", "zone", "region"]) el(id).addEventListener("input", renderCatalog);
  for (const id of ["recipe", "servings"]) el(id).addEventListener("input", () => {
    el("recipe-result").textContent = "";
    renderRecipes();
  });
  el("recipe").value = 6290;
  el("lookup-controls").disabled = false;
  el("recipe-controls").disabled = false;
  renderCatalog();
  renderRecipes();

  let records = [];
  function resetPreview() {
    records = [];
    el("preview-body").replaceChildren();
    el("preview-results").hidden = true;
    el("submit-status").textContent = "";
  }
  el("record-code").addEventListener("input", resetPreview);
  el("preview-button").disabled = false;
  function previewRecords() {
    resetPreview();
    try {
      records = parseRecords(el("record-code").value);
      if (records.some((row) => !byID.has(row.item))) throw new Error("item");
      appendRecords(el("preview-body"), records, false);
      el("preview-results").hidden = false;
    } catch {
      records = [];
      el("submit-status").textContent = t("无法读取记录。请粘贴一整段 WFDB1 记录，最多 20 组，且不能重复。",
        "Could not read the records. Paste one complete WFDB1 code with up to 20 unique groups.");
    }
  }
  el("submit-form").addEventListener("submit", (event) => {
    event.preventDefault();
    previewRecords();
  });

  el("prepare-post").addEventListener("click", () => {
    if (!records.length || !el("credit").reportValidity()) return;
    const credit = el("credit").value.trim().replace(/[\r\n]/g, "");
    const code = "WFDB1:" + records.map((row) => Object.values(row).join(",")).join(";");
    el("post-text").value = t("WFDB 钓鱼实测投稿", "WFDB fishing observation") + "\n" +
      (credit ? t("署名 ", "Credit ") + credit : t("匿名", "Anonymous")) + "\n\n" + code;
    el("post-area").hidden = false;
    el("post-text").focus();
    el("post-text").select();
  });
  el("post-area").hidden = true;
  for (const id of ["record-code", "credit"]) el(id).addEventListener("input", () => { el("post-area").hidden = true; });
  if (location.hash.startsWith("#preview=")) {
    const raw = location.hash.slice(9);
    history.replaceState(null, "", "#submit");
    try {
      if (raw.length <= 4200) el("record-code").value = "WFDB1:" + decodeURIComponent(raw);
    } catch {
      el("record-code").value = "";
    }
    previewRecords();
    el("submit").scrollIntoView();
  }
}
if (typeof document !== "undefined" && el("lookup")) {
  start().catch(() => {
    el("result-count").textContent = t("暂时无法加载鱼类资料，请刷新重试。", "Could not load the catalog. Reload to try again.");
  });
}
