# scripts/02_load_wdi.R
# Run from the project root.
# Default: reads the PINNED raw WDI pull in 02_data/raw/wdi/<YYYY-MM-DD>/ (latest dated folder);
# no internet needed. Pass --live (Rscript 03_code/02_load_wdi.R --live) to hit the World Bank
# API instead: that saves a new dated raw pull and then proceeds from it.
# NOTE: the thesis results rest on the June 2026 pull stored in
# 02_data/processed/wdi_popgrowth.rds, not on the pinned raw pull; see README.md.
# tidyverse components (loaded individually to avoid the meta-package's
# system-font build dependencies; behaviour is identical)
library(dplyr); library(tidyr); library(readr); library(stringr)
library(purrr); library(tibble); library(ggplot2)

pin_root <- "02_data/raw/wdi"

if ("--live" %in% commandArgs(trailingOnly = TRUE)) {
  library(wbstats)
  live <- wb_data(
    indicator = "SP.POP.GROW",
    country   = c(  # WB uses ISO2 — wbstats handles this internally
      "AU","AT","BE","CA","DK","FI","FR","DE","GR","IE","IT","JP",
      "NL","NZ","NO","PT","ES","SE","CH","TR","GB","US","MX","IS"
    ),
    start_date = 1995,
    end_date   = 2019
  )
  dir.create(file.path(pin_root, Sys.Date()), recursive = TRUE, showWarnings = FALSE)
  write.csv(as.data.frame(live),
            file.path(pin_root, Sys.Date(), "wdi_SP.POP.GROW_raw.csv"), row.names = FALSE)
}

pins <- sort(list.files(pin_root, pattern = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"))
if (length(pins) == 0) stop("No pinned WDI pull in ", pin_root, "; run with --live.")
pin_file <- file.path(pin_root, tail(pins, 1), "wdi_SP.POP.GROW_raw.csv")
cat("Reading pinned WDI pull:", pin_file, "\n")

wdi_raw <- read.csv(pin_file, stringsAsFactors = FALSE) |>
  rename(
    countrycode   = iso3c,
    year          = date,
    pop_growth_wb = SP.POP.GROW
  ) |>
  select(countrycode, year, pop_growth_wb) |>
  mutate(year = as.integer(year)) |>
  arrange(countrycode, year)

saveRDS(wdi_raw, "02_data/processed/wdi_popgrowth.rds")
