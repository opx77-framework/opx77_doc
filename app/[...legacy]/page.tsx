import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { legacyRedirects } from "@/lib/legacy";
import { basePath } from "@/lib/shared";

export const dynamicParams = false;

export function generateStaticParams() {
  return Object.keys(legacyRedirects).map((path) => ({ legacy: path.split("/") }));
}

export const metadata: Metadata = { robots: { index: false } };

// One static page per URL the MkDocs site served: it forwards to the page that
// answers it now, keeping the #fragment when some page still defines it.
export default async function Legacy(props: PageProps<"/[...legacy]">) {
  const { legacy } = await props.params;
  const target = legacyRedirects[legacy.join("/")];
  if (!target) notFound();

  const href = `${basePath}${target}/`;
  const script = `(function(){
  var base=${JSON.stringify(basePath)}, target=${JSON.stringify(target)}, hash=location.hash.slice(1);
  function go(route){ location.replace(base + route + "/" + (hash ? "#" + hash : "")); }
  if (!hash) return go(target);
  fetch(base + "/anchors.json").then(function(r){ return r.json(); }).then(function(all){
    var pages = all[decodeURIComponent(hash)] || [];
    var same = pages.filter(function(p){ return p === target || p.indexOf(target + "/") === 0; });
    go(same[0] || (pages.length === 1 ? pages[0] : target));
  }).catch(function(){ go(target); });
})();`;

  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-2 p-8 text-center">
      <meta httpEquiv="refresh" content={`3; url=${href}`} />
      <p>This page has moved.</p>
      <a className="underline underline-offset-4" href={href}>
        Continue to {target}
      </a>
      <script dangerouslySetInnerHTML={{ __html: script }} />
    </main>
  );
}
