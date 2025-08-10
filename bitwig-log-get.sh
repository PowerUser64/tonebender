#!/bin/bash
# get the plugin logs from bitwig and print them with syntax highlighting
# requires: grc (generic colorizer)

grc -c conf.common tail -f ~/.BitwigStudio/log/engine.log
