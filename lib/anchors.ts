import { join } from "node:path";
// The one definition of an anchor, shared with the coverage and content checks.
import { collect, listPages } from "@/scripts/anchors.mjs";

/** Every anchor id on the site -> the docs routes that define it. Build time only. */
export function anchorIndex(): Record<string, string[]> {
  const content = join(process.cwd(), "content", "docs");
  const out: Record<string, string[]> = {};
  for (const [url, page] of collect(listPages(content), content)) {
    for (const anchor of page.anchors) (out[anchor] ??= []).push(url);
  }
  return out;
}
