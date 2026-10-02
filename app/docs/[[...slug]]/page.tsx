import { getPageMarkdownUrl, source } from "@/lib/source";
import {
  DocsBody,
  DocsDescription,
  DocsPage,
  DocsTitle,
  EditOnGitHub,
  PageLastUpdate,
  ViewOptionsPopover,
} from "fumadocs-ui/layouts/docs/page";
import { notFound } from "next/navigation";
import { getMDXComponents } from "@/components/mdx";
import type { Metadata } from "next";
import { createRelativeLink } from "fumadocs-ui/mdx";
import { appName, basePath, gitConfig } from "@/lib/shared";

export default async function Page(props: PageProps<"/docs/[[...slug]]">) {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const MDX = page.data.body;
  const markdownUrl = `${basePath}${getPageMarkdownUrl(page).url}`;

  const footer = (
    <div className="flex flex-row gap-2">
      <ViewOptionsPopover markdownUrl={markdownUrl} />
      <EditOnGitHub
        href={`https://github.com/${gitConfig.user}/${gitConfig.repo}/blob/${gitConfig.branch}/content/docs/${page.path}`}
      />
    </div>
  );

  return (
    <DocsPage
      breadcrumb={{ includeRoot: true, includePage: false }}
      toc={page.data.toc}
      full={page.data.full}
      tableOfContent={{ footer }}
      tableOfContentPopover={{ footer }}
    >
      <DocsTitle className="flex items-end justify-between gap-4">
        {page.data.title}
        {page.data.lastModified && (
          <PageLastUpdate className="text-xs font-medium pb-2" date={page.data.lastModified} />
        )}
      </DocsTitle>
      <DocsDescription className="mb-0">{page.data.description}</DocsDescription>
      <DocsBody>
        <MDX components={getMDXComponents({ a: createRelativeLink(source, page) })} />
      </DocsBody>
    </DocsPage>
  );
}

export async function generateStaticParams() {
  return source.generateParams();
}

export async function generateMetadata(props: PageProps<"/docs/[[...slug]]">): Promise<Metadata> {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  // "Server - weather", "AddMoney - server": the folder a page sits in names it.
  const section = page.slugs.at(-2);
  const title = section ? `${page.data.title} - ${section}` : page.data.title;

  return {
    title: title === appName ? undefined : title,
    description: page.data.description,
  };
}
