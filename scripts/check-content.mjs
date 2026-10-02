#!/usr/bin/env node
// check-content.mjs — fast checks over content/docs, without a Next build.
//
//   1. every .mdx compiles as MDX (GFM on, as Fumadocs does): a stray `{` or
//      `<` outside a code span fails here instead of in `next build`;
//   2. every front matter has a `title` and a `description`;
//   3. every internal link `/docs/...` (or relative `./x`, `../x`) resolves to a
//      page, and its `#anchor`, when it has one, exists on that page;
//   4. no anchor id is defined twice on the same page.
//
// Usage: node scripts/check-content.mjs [file-or-dir ...]   (default: all)
// Exit code 1 on any problem. Anchors are collected exactly as the coverage
// check collects them (scripts/anchors.mjs).

import { readFileSync } from "node:fs";
import { relative, resolve } from "node:path";
import { compile } from "@mdx-js/mdx";
import remarkGfm from "remark-gfm";
import { CONTENT, collect, listPages, pageUrl, parseFrontMatter } from "./anchors.mjs";

const args = process.argv.slice(2);
const pages = listPages();
const index = collect(pages); // url -> { file, anchors:Set, dupes:[] }

const only = args.length
  ? pages.filter((file) => args.some((arg) => resolve(file).startsWith(resolve(arg))))
  : pages;

let problems = 0;
const report = (file, message) => {
  problems++;
  console.error(`${relative(process.cwd(), file)}: ${message}`);
};

const LINK = /\]\(([^)\s]+)\)|href="([^"]+)"/g;

for (const file of only) {
  const text = readFileSync(file, "utf8");
  const { data, body } = parseFrontMatter(text);
  if (!data.title) report(file, "front matter has no title");
  if (!data.description) report(file, "front matter has no description");

  try {
    await compile(body, { remarkPlugins: [remarkGfm] });
  } catch (error) {
    const where = error.line ? `line ${error.line + (text.split("\n").length - body.split("\n").length)}` : "";
    report(file, `MDX does not compile ${where}: ${error.reason ?? error.message}`);
  }

  const self = index.get(pageUrl(file));
  for (const dupe of self.dupes) report(file, `anchor #${dupe} defined twice`);

  // Links, outside fenced code.
  const prose = body.replace(/^(```|~~~)[\s\S]*?^\1/gm, "");
  for (const match of prose.matchAll(LINK)) {
    const raw = match[1] ?? match[2];
    if (/^(https?:|mailto:|#$)/.test(raw)) continue;
    let [path, hash] = raw.split("#");
    let target;
    if (path === "") target = self;
    else if (path.startsWith("/docs")) target = index.get(path.replace(/\/$/, "") || "/docs");
    else if (path.startsWith(".")) {
      const url = new URL(path.replace(/\.mdx$/, ""), `http://x${pageUrl(file)}/`).pathname.replace(/\/$/, "");
      target = index.get(url);
    } else if (path.startsWith("/")) continue; // other site routes
    else continue;
    if (!target) {
      report(file, `link to a missing page: ${raw}`);
      continue;
    }
    if (hash && !target.anchors.has(hash)) report(file, `link to a missing anchor: ${raw}`);
  }
}

console.log(`check-content: ${only.length} page(s) checked, ${problems} problem(s).`);
process.exit(problems ? 1 : 0);
