import { BookIcon, Boxes, Code, FileQuestion } from "lucide-react";
import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { appName, gitConfig } from "./shared";

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: <span className="font-mono font-bold tracking-tight">{appName}</span>,
      url: "/docs",
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
    links: [
      { type: "main", text: "Documentation", url: "/docs", icon: <BookIcon />, on: "nav" },
      { type: "main", text: "opx_infinity", url: "/docs/opx_infinity", icon: <Boxes />, on: "all" },
      { type: "main", text: "Creators", url: "/docs/creators", icon: <Code />, on: "all" },
      { type: "main", text: "Guides", url: "/docs/guides", icon: <FileQuestion />, on: "all" },
    ],
  };
}
