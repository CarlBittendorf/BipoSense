# BipoSense

## Introduction

The BipoSense study offers continous passive and active sensing data over 12 months from 29 patients with bipolar disorder. Specifically, clinical interviews were conducted every two weeks (a total of 26 per person), allowing for a precise assessment of depressive and manic episodes. Our goal is to develop approaches to reliably detect upcoming episodes using early warning signals, which would enable interventions to mitigate or prevent these episodes.

This repository contains the code for data processing, analysis and visualization, written in [Julia](https://julialang.org/). It is intended to serve as a non-ambiguous documentation of our approach and as a starting point or reference for future studies in this research area.

## Overview

Generally, each folder in this repository corresponds to a project or article. The exception is *Common*, which is an (unregistered) Julia package that contains functionality used across multiple projects. Each project or analysis typically consists of three main steps:

1. *Features* are calculated (usually through aggregation) from the raw data, for example, the number of calls, the distance traveled, or the time spent in shopping malls per day.

2. *Frameworks* are used to generate predictions from the features. Currently implemented frameworks are EWMA-based Statistical Process Control (SPC) and Dynamical Systems Theory (DST).

3. *Evaluation*, for example, through generalized linear mixed-effects models (including correction for multiple testing, automatic generation of model tables), statistical measures (sensitivity, specificity, etc.), ROC curves, and so on.

In addition, data is visualized in a variety of ways, especially as time series with plotted episodes. Each project contains the following files and folders:

* *Project.toml* and *Manifest.toml*: These two files list the required Julia packages, their dependencies and the versions used in this project.

* *Data.toml*: This file, along with [DataToolkit.jl](https://github.com/tecosaur/DataToolkit.jl), is used to organize and manage our data and contains, among other things, descriptions, checksums and references to the code that was used to create the datasets.

* *scripts*: Contains the specific code for processing data, fitting models, creating figures and so on.

### Passive Sensing

Passive data collection via smartphone offers a promising opportunity to capture changes in activity, communication, or sleep. We investigate the potential of statistical process control to detect these changes and thus predict upcoming affective episodes.

### Critical Slowing Down

Dynamic systems theory predicts a so-called "critical slowdown" before a phase transition, in which the system becomes more sensitive to stimuli, manifesting as stronger autocorrelation and variance. Here, we investigate whether this phenomenon precedes depressive and (hypo)manic episodes using smartphone-based digital phenotyping.

### Unique Places

We investigate whether exploratory behavior, operationalized via smart digital phenotypes (unique places visited, frequency of location changes, time spent at each location), can predict emerging episodes.

### Crowded Places

Changes in preferred environments or spatial routines are core symptoms of bipolar disorder. We investigate whether impending episodes can be predicted by urban exposure (i.e., population density, surface imperviousness, busy public spaces, and green spaces).

## Acknowledgements

Funded by the Deutsche Forschungsgemeinschaft (DFG, German Research Foundation) – GRK2739/1 – Project Nr. 447089431 – Research Training Group: KD²School – Designing Adaptive Systems for Economic Decisions