const stats = document.getElementById("catalog-stats");

try {
  const response = await fetch(new URL("fishing/catalog.json", import.meta.url));
  if (response.ok) {
    const { fish, recipes } = await response.json();
    const format = new Intl.NumberFormat(document.documentElement.lang);
    document.getElementById("fish-total").textContent = format.format(fish.length);
    document.getElementById("recipe-total").textContent = format.format(recipes.length);
    stats.hidden = false;
  }
} catch {
  // The search and section links remain usable if the catalog is unavailable.
}
