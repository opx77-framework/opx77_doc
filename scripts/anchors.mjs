// anchors.mjs — the anchors every page of content/docs defines.
//
// An anchor is any id a URL fragment can land on:
//   - a heading's explicit id:       ## SetTime [#server-weather-settime]
//   - a heading's generated id:      ## Commands            -> #commands
//     (github-slugger, the same slugger Fumadocs uses, reset per page)
//   - an element's id attribute:     <a id="config-weather-enabled" />
//
// Used by check-content.mjs (links) and check-api-coverage.sh (coverage), and
// runnable on its own: `node scripts/anchors.mjs` prints
// "<file relative to content/docs>\t<anchor>" for every anchor.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import GithubSlugger from "github-slugger";

const ROOT = resolve(fileURLToPath(import.meta.url), "../..");
export const CONTENT = join(ROOT, "content", "docs");

export function listPages(dir = CONTENT) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) out.push(...listPages(full));
    else if (name.endsWith(".mdx")) out.push(full);
  }
  return out.sort();
}

export function pageUrl(file) {
  const rel = relative(CONTENT, file).split(sep).join("/").replace(/\.mdx$/, "");
  const path = rel === "index" ? "" : rel.replace(/\/index$/, "");
  return path ? `/docs/${path}` : "/docs";
}

export function parseFrontMatter(text) {
  const match = /^---\r?\n([\s\S]*?)\r?\n---\r?\n?/.exec(text);
  if (!match) return { data: {}, body: text };
  const data = {};
  for (const line of match[1].split(/\r?\n/)) {
    const kv = /^(\w+):\s*(.*)$/.exec(line);
    if (kv) data[kv[1]] = kv[2].replace(/^["']|["']$/g, "");
  }
  return { data, body: text.slice(match[0].length) };
}

// Visible text of a heading, roughly as mdast would flatten it.
function headingText(raw) {
  return raw
    .replace(/`([^`]*)`/g, "$1")
    .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
    .replace(/<[^>]+>/g, "")
    .replace(/(\*\*|__|\*|_)(.+?)\1/g, "$2")
    .trim();
}

export function anchorsOf(text) {
  const { body } = parseFrontMatter(text);
  const slugger = new GithubSlugger();
  const anchors = [];
  let fence = null;
  for (const line of body.split(/\r?\n/)) {
    const open = /^\s*(```+|~~~+)/.exec(line);
    if (open) {
      if (!fence) fence = open[1];
      else if (line.trim().startsWith(fence)) fence = null;
      continue;
    }
    if (fence) continue;
    const heading = /^(#{1,6})\s+(.*?)\s*$/.exec(line);
    if (heading) {
      const custom = /\s*\[#([^\]]+?)\]\s*$/.exec(heading[2]);
      if (custom) anchors.push(custom[1]);
      else anchors.push(slugger.slug(headingText(heading[2])));
    }
    for (const match of line.matchAll(/\bid=["']([^"']+)["']/g)) anchors.push(match[1]);
  }
  return anchors;
}

export function collect(pages = listPages()) {
  const index = new Map();
  for (const file of pages) {
    const anchors = anchorsOf(readFileSync(file, "utf8"));
    const seen = new Set();
    const dupes = [];
    for (const anchor of anchors) {
      if (seen.has(anchor)) dupes.push(anchor);
      seen.add(anchor);
    }
    index.set(pageUrl(file), { file, anchors: seen, dupes });
  }
  return index;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  for (const file of listPages()) {
    const rel = relative(CONTENT, file).split(sep).join("/");
    for (const anchor of anchorsOf(readFileSync(file, "utf8"))) console.log(`${rel}\t${anchor}`);
  }
}
