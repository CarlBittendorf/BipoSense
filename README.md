# Predicting depressive and manic episodes in patients with bipolar disorder using statistical process control methods on passive sensing data

## Overview

This repository contains the code for data processing, optimization and creating figures, written in [Julia](https://julialang.org/). It is intended to serve as a non-ambiguous documentation of our approach and as a starting point or reference for data processing in future studies in this research area.

Here is a quick overview of various files and folders of interest:
* *Project.toml* and *Manifest.toml*: These two files list the required Julia packages, their dependencies and the versions used in this project.
* *Data.toml*: This file, along with [DataToolkit.jl](https://github.com/tecosaur/DataToolkit.jl), is used to organize and manage our data and contains, among other things, descriptions, checksums and references to the code that was used to create the datasets.
* *src*: This directory contains relatively general functions that could easily be reused in other projects. For example, to download and process data from [movisens](https://www.movisens.com/en/), calculate classification metrics or create plots for statistical process control.
* *scripts*: Contains specific code for loading, transforming and saving data, optimizing parameters and creating figures.
