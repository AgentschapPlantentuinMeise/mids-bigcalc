# Mass MIDS calculation
This repository contains code to upscale MIDS calculations to levels that are time-intensive and clunky to do with the [MIDSCalculator](https://github.com/AgentschapPlantentuinMeise/MIDSCalculator) code. It reuses big parts of the MIDSCalculator tool, but without an Rshiny interface and with slight tweaks to support products exported through GBIF's SQL API.

It makes use of a big export from GBIF requested through the SQL API for all specimens with dwc:basisOfRecord = PreservedSpecimen, creating this download: https://doi.org/10.15468/dl.taw6xr The specific query used can also be found there. The file is massive, ca. 110GB uncompressed.

To calculate MIDS levels and element scores efficiently, a script was made called `explo.R`. This script reuses functions from the MIDSCalculator app (see the relative path `calcpath` to the app's code) and introduces a few tweaks, mainly removing Darwin Core (and other) namespaces and classes, as well as setting terms to lower case. The script also uses a customized SSSOM mapping for this reason, included in this repo.

The big CSV file is subsequently read in batches of 10M (27 batches required to process ca. 270M specimen records). The results are saved as tsv files with binary values for each MIDS element (1 if met, 0 if not) and the overall MIDS level achieved. The gbifID and datasetKey are not included to save storage, but could be inferred from the original big GBIF download file if needed, though this may be computationally intensive.

Each batch takes 3-5 minutes on an Ubuntu 22 laptop with a i7-1265U with 12 cores and 36 GB RAM. The code is not parallelized, so this could be optimized by using multiple cores instead of 1. RAM was never a bottleneck in principle (max about 50%), but I encountered problems with swap memory, even causing forced reboots due to OOM. These did not rematerialize after introducing forced memory cleaning after each batch, but swap continues to get maxed out after each read operation.

The result is 27 csv files of about 380 MB each. The bash scripts `midslevel.sh` and `allcounts.sh` generate summary results, making use of awk - the former counting the frequency of values for a single column, and the latter looping through a series of columns. Especially the latter script may take some time to complete.

The `analyze_counts.R` script generates a barchart showing the summary results from `allcounts.sh`.

# TO DO
- Optimize processing by introducing parallel compute and solving the swap memory issues.
- Document the mapping tweaks and potential problems with the SQL API (e.g. mids:MediaID is not mapped to anything available through the SQL API, so mids3 is unreachable through this method).
- More in depth-analysis of why some elements are met and others not, in particular the relatively high frequency of mids-1 due to missing mids:Organization data.
