#!/bin/bash

set -e

eval "./compile.sh $@"
eval "./run.sh $@"
