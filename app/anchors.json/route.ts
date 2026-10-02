import { anchorIndex } from "@/lib/anchors";

export const dynamic = "force-static";

// Read by the old-URL redirect pages to carry a #fragment to the page that
// now defines it.
export function GET() {
  return Response.json(anchorIndex());
}
