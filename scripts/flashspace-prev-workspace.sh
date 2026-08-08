#!/usr/bin/env bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title FlashSpace Previous Workspace
# @raycast.mode silent
# @raycast.packageName FlashSpace

/opt/homebrew/bin/flashspace workspace --prev --loop --skip-empty
