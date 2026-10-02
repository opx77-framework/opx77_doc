import { createMDX } from "fumadocs-mdx/next";

const withMDX = createMDX();

// Served by GitHub Pages at https://opx77-framework.github.io/opx77_doc/,
// so every route and asset lives under /opx77_doc. `trailingSlash` emits
// `page/index.html`, which is what Pages serves for `/page/` (the URL shape
// the MkDocs site used, so old links keep resolving).
export const basePath = "/opx77_doc";

/** @type {import('next').NextConfig} */
const config = {
  output: "export",
  basePath,
  trailingSlash: true,
  reactStrictMode: true,
  images: { unoptimized: true },
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
};

export default withMDX(config);
