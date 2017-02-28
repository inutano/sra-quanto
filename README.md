# SRA Quanto

SRA Quanto is a project to calculate quantitative information of high-throughput sequencing data archived in sequence read archive (SRA) to enhance reuse of the publc sequencing data. This repository contains the code to calculate statistics using FastQC, summarize using biogem bio-fastqc, and visualize by R.

## Summarized data

Calculated and summarized quality statistics is available at [Figshare](https://figshare.com/articles/quanto_data_20161021_tsv/4498907) in tabular format including submitter's metadata such as sequencing methods and sample organisms. Statistics for each sequencing run is available in RDF format, and [NBDC RDF Portal](https://integbio.jp/rdf) is providing summary of RDF data, SPARQL endpoint, and example queries [here](https://integbio.jp/rdf/?view=detail&id=quanto).

## Requirement for data calculation

- Ruby (2.3.0)
  - [bundler](http://bundler.io)
- Univa Grid Engine (8.4.0) for parallelized FastQC execution
- R (ver. 3.2.3) and ggplot2 (ver. 2.1.0) for visualization

## Usage

Setup rubygems

```sh
$ git clone https://github.com/inutano/sra-quanto
$ cd sra-quanto
$ bundle install --path=vendor/bundle
# show rake tasks
$ bundle exe rake -T
rake quanto:available  # option: workdir, fastqc_dir, sra_metadata_dir, biosample_metadata_dir
rake quanto:exec       # option: workdir, fastqc_dir
rake quanto:plot       # option: data (default: tables/summary/quanto.annotated.tsv)
rake quanto:summarize  # option: workdir, sra_metadata_dir, summary_outdir, overwrite, format
```

### Calculate statistics

```sh
# Create list of available sequencing runs
$ bundle exe rake quanto:available workdir=/path/to/working_directory fastqc_dir=/path/to/dir_to_save_fastqc_result
# Start calculation, it may take very long time.
$ bundle exe rake quanto:execute
# Summarize in tsv
$ bundle exe rake quanto:summarize workdir=/path/to/working_directory format=tsv
```

### Visualization

```sh
$ bundle exe rake quanto:plot data=/path/to/summarized_tsv
```

## Citation

Please cite the data on figshare with doi [10.6084/m9.figshare.4498907.v2](https://doi.org/10.6084/m9.figshare.4498907.v2). The current published data is version 2.

## Copyright

Copyright (c) 2015 Tazro Inutano Ohta. See LICENSE.txt for further details.
