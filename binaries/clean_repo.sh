#!/bin/bash
find . -name "*.pyc" -exec rm -f {} \;
find . -name "*.orig" -exec rm -f {} \;
