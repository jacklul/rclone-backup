#!/usr/bin/env bash

# Remove temporary directory
if [ -d "$TMP_DIR" ] && [[ "$TMP_DIR" == /tmp* ]]; then
    rm -fr "$TMP_DIR"
fi
