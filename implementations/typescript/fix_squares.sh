#!/bin/bash
# This script will be used to understand the patterns
npm run build 2>&1 | grep "error TS" | grep -o "src/[^(]*" | sort -u
