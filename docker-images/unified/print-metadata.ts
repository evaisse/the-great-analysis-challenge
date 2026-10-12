#!/usr/bin/env bun
// Prints a single resolved chess.meta / org.chess.* metadata field for an
// implementation, reusing the same parser as the rest of the shared
// tooling (tooling/shared.ts getMetadata) so the unified image's
// entrypoint never re-implements Dockerfile LABEL parsing.
import { parseArgs } from "node:util";

import { getMetadata, resolveImplPath } from "../../tooling/shared.ts";

const { values } = parseArgs({
  options: {
    impl: { type: "string" },
    field: { type: "string" },
  },
});

if (!values.impl || !values.field) {
  console.error("Usage: print-metadata.ts --impl <name|path> --field <metadata-field>");
  process.exit(1);
}

const metadata = await getMetadata(resolveImplPath(values.impl));
const value = metadata[values.field];
if (value === undefined || value === null || String(value).trim() === "") {
  process.exit(1);
}
console.log(String(value));
