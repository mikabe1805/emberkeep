import {existsSync} from "node:fs";
import path from "node:path";

export function resolveMarketingRoot(appRoot) {
  const candidates = [];
  const override = process.env.ROOM_OF_DAYS_MARKETING_ROOT?.trim();
  if (override) candidates.push(path.resolve(override));

  let ancestor = path.dirname(path.resolve(appRoot));
  for (let depth = 0; depth < 6; depth += 1) {
    candidates.push(path.join(ancestor, "marketing_site"));
    const parent = path.dirname(ancestor);
    if (parent === ancestor) break;
    ancestor = parent;
  }

  for (const candidate of new Set(candidates)) {
    if (existsSync(path.join(candidate, "src", "App.jsx"))) {
      return candidate;
    }
  }

  throw new Error(
    `marketing_site was not found near ${appRoot}. ` +
      "Set ROOM_OF_DAYS_MARKETING_ROOT to its checkout path.",
  );
}
