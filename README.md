# Replication Package

## Paper Title
**Early-Life Health and Human Capital: Low-Birthweight Births and NAEP Math Scores in the United States**

## Author
Darío Cáceres

## Overview
This replication package contains the data and R code used in the paper and presentation. The project studies the relationship between low-birthweight births and 8th-grade NAEP mathematics scores across U.S. states.

The package includes:
- raw and merged data files
- the main R analysis script
- instructions for reproducing the results

## Files Included

### Data files
- `merged_naep_lbw.xlsx`  
  Main merged dataset containing NAEP math scores and low-birthweight birth counts by state and year.

- `Natality, 2007-2024.csv`  
  Total births by state and year. Used to construct the low-birthweight rate.

- `SAINC1__ALL_AREAS_1929_2024.csv`  
  BEA state personal income file. Used to construct per capita personal income.

- `ELSI_csv_export_6391131616929783805927.csv`  
  NCES education spending file. Used to construct per-pupil spending.

- `The_Tax_Burden_on_Tobacco,_1970-2019_20260430.csv`  
  State cigarette tax data. Used in the instrumental variables attempt.

### Code file
- `naep_lbw.R`  
  Main R script containing data cleaning, merging, regressions, alternative specifications, and table-generation code.

## Software Requirements
This project was completed in **R**.

### Required R packages
- `readxl`
- `readr`
- `dplyr`
- `tidyr`
- `stringr`
- `janitor`
- `fixest`
- `gt`

To install them in R:

```r
install.packages(c("readxl", "readr", "dplyr", "tidyr", "stringr", "janitor", "fixest", "gt"))
```

## How to Run the Replication Package
1. Download all files in this replication package into the same folder.
2. Open `naep_lbw.R` in R or RStudio.
3. Update file paths if necessary.
4. Run the script from top to bottom.

## What the Script Does

### 1. Fixed-effects model with controls
The script:
- merges NAEP, total births, income, and spending data
- constructs the low-birthweight rate
- estimates a two-way fixed effects model with:
  - low-birthweight rate
  - per capita personal income
  - per-pupil spending

### 2. Main fixed-effects count model
The script:
- uses the merged NAEP + low-birthweight count file
- estimates the preferred model:
  - dependent variable: `naep_score`
  - independent variable: `lbw_thousands`
  - state fixed effects
  - year fixed effects
  - clustered standard errors by state

### 3. Alternative specification
The script also estimates a 2-year average version of low-birthweight births to address the mismatch between annual natality data and biannual NAEP data.

### 4. Instrumental variables attempt
The script merges state cigarette tax data and estimates:
- first stage
- reduced form
- IV regression

This IV specification is included as an extension and is not the preferred result because the first stage is weak.

## Preferred Specification
The preferred result in the paper/presentation is the **same-year fixed-effects count model**, using:
- `naep_score` as the dependent variable
- `lbw_thousands` as the main independent variable
- state fixed effects
- year fixed effects
- clustered standard errors by state

## Notes
- Some alternative specifications drop observations because of missing values after merging additional controls.
- The IV specification is included for transparency but is not used as the main result.
- The code currently contains absolute file paths from the author's computer. If replicating on another machine, these paths should be changed to local or relative paths.
- The script also contains a table-generation section.

## AI Use Disclosure
AI was used to assist with code troubleshooting, organization, and table formatting.
