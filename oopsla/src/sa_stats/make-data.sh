#!/bin/bash

# file with the list of packages to analyze
PKGSLIST="../pkgs_list/pkgs-test-suit.txt"

if [ $# -gt 0 ]
then
	PKGSLIST=$1
fi

echo "=== SASTATS-INFO: Gathering statistics..."
JULIA_PKGDIR=../../stats/JuliaCache julia make-data.jl $PKGSLIST ../../stats/agg.json && \
echo "=== SASTATS-INFO: Gathering statistics completed" && \
echo "=== SASTATS-INFO: Generating figures..." && \
cd ../../stats && \
Rscript -e 'rmarkdown::render("make_figure.Rmd")' && \
echo "=== SASTATS-INFO: Generating figures completed" && \
cp make_figure.html ~/types_stat.html && \
echo "=== SASTATS-INFO: Find results in ~/types_stat.html"
