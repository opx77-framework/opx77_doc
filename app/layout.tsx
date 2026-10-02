import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import { Provider } from "@/components/provider";
import { appName, siteUrl } from "@/lib/shared";
import "./global.css";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });
const mono = JetBrains_Mono({ subsets: ["latin"], variable: "--font-jetbrains" });

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: { default: appName, template: `%s | ${appName}` },
  description: "Documentation for OPX//77, the roleplay framework for Open77 (multiplayer Cyberpunk 2077).",
};

export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <html lang="en" className={`${inter.variable} ${mono.variable}`} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen font-sans">
        <Provider>{children}</Provider>
      </body>
    </html>
  );
}
