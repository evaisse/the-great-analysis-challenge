#!/usr/bin/env bun

import { runSemanticTokensCli } from "../../tooling/semantic-tokens.ts";

const exitCode = await runSemanticTokensCli(process.argv.slice(2));
process.exit(exitCode);
