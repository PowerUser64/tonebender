#!/bin/bash
# gcc fails for some reason
../generate-c-code.sh ./sine.dsp && g++ ./main.c && ./a.out
