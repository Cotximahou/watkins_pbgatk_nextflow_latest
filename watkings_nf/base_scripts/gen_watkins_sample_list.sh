#!/bin/bash

find "$1" -type f -name *.fastq.gz |xargs -n 1 basename |cut -d "_" -f 1 |sort |uniq
