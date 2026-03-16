#!/usr/bin/env bun

import { main } from "./tooling/cli.ts";

const exitCode = await main(process.argv.slice(2));
process.exit(exitCode);
