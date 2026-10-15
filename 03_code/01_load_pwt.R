# scripts/01_load_pwt.R
# Run from the project root (all paths are relative to it).
library(haven)
# tidyverse components (loaded individually to avoid the meta-package's
# system-font build dependencies; behaviour is identical)
library(dplyr); library(tidyr); library(readr); library(stringr)
library(purrr); library(tibble); library(ggplot2)

# ── 1. Load raw PWT (version 11.0) ────────────────────────────────────────────
pwt_raw <- read_dta("02_data/raw/pwt110.dta")

# Inspect: check variable labels are intact
glimpse(pwt_raw)
# attr(pwt_raw$rgdpna, "label")  # should read "Real GDP at constant 2017 national prices"

# ── 2. OECD pre-1995 membership list ─────────────────────────────────────────
# ISO3 codes for 24 members. Luxembourg excluded (micro-state, standard exclusion);
# Iceland (ISL) IS retained in the main sample, with a robustness check dropping it.
oecd_1995 <- c(
  "AUS", "AUT", "BEL", "CAN", "DNK", "FIN", "FRA", "DEU",
  "GRC", "IRL", "ITA", "JPN", "NLD", "NZL", "NOR", "PRT",
  "ESP", "SWE", "CHE", "TUR", "GBR", "USA", "MEX", "ISL"
)
# NOTE: Turkey (TUR) and Mexico (MEX) are borderline — keep for now,
# run robustness checks without them. Flag for supervisor.

# ── 3. Select variables and filter ───────────────────────────────────────────
pwt <- pwt_raw |>
  select(countrycode, country, year, rgdpna, pop, hc, csh_i, emp) |>
  filter(
    countrycode %in% oecd_1995,
    year >= 1995,
    year <= 2019
  ) |>
  # Standardise: ensure countrycode is character, year is integer
  mutate(
    countrycode = as.character(countrycode),
    year        = as.integer(year)
  ) |>
  arrange(countrycode, year)

# ── 4. Quick completeness check ───────────────────────────────────────────────
# How many obs per country? Should be 25 (1995–2019 inclusive)
pwt |>
  count(countrycode, country) |>
  print(n = 30)

# Which country-years are missing key variables?
pwt |>
  filter(if_any(c(rgdpna, pop, hc, csh_i, emp), is.na)) |>
  select(countrycode, year, rgdpna, pop, hc, csh_i, emp) |>
  print(n = 50)

# ── 5. Save ───────────────────────────────────────────────────────────────────
saveRDS(pwt, "02_data/processed/pwt_filtered.rds")
