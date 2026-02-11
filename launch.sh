#!/bin/bash
exec ralph-runs --max=2 \
  git@github.com:mgreenly/ikigai.git \
  git@github.com:ai4mgreenly/ralph-runs
