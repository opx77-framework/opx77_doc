import Link from "next/link";

const entries = [
  { href: "/docs/getting-started/install", title: "Install a server", text: "opx_infinity, opx_lib, the database and the ACL." },
  { href: "/docs/opx_infinity", title: "opx_infinity", text: "The runtime and its modules: contracts, commands, events, config." },
  { href: "/docs/creators", title: "Creators", text: "Exports and public events for your own resources." },
  { href: "/docs/opx_lib", title: "opx_lib", text: "The client library any resource can require." },
];

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-10 px-4 py-16 text-center">
      <div className="flex flex-col items-center gap-3">
        <h1 className="font-mono text-4xl font-bold tracking-tight sm:text-5xl">OPX//77</h1>
        <p className="max-w-xl text-fd-muted-foreground">
          A roleplay framework for Open77, the multiplayer platform for Cyberpunk 2077. One resource,{" "}
          <code>opx_infinity</code>, plus the <code>opx_lib</code> client library.
        </p>
      </div>
      <div className="grid w-full max-w-3xl gap-3 sm:grid-cols-2">
        {entries.map((entry) => (
          <Link
            key={entry.href}
            href={entry.href}
            className="rounded-lg border bg-fd-card p-4 text-left transition-colors hover:bg-fd-accent"
          >
            <p className="font-medium">{entry.title}</p>
            <p className="text-sm text-fd-muted-foreground">{entry.text}</p>
          </Link>
        ))}
      </div>
      <Link href="/docs" className="text-sm font-medium underline underline-offset-4">
        Continue to documentation →
      </Link>
    </main>
  );
}
