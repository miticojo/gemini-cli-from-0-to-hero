#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../../../../backend"
firebase emulators:exec --only firestore "echo rules loaded"
