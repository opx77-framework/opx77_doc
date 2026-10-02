export const appName = "OPX//77";
export const docsRoute = "/docs";
export const docsContentRoute = "/llms.mdx/docs";

// Set by next.config.mjs. Raw <img>/<a> tags and fetches need it; next/link
// and the router add it on their own.
export const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export const siteUrl = "https://opx77-framework.github.io/opx77_doc";

export const gitConfig = {
  user: "opx77-framework",
  repo: "opx77_doc",
  branch: "main",
};
