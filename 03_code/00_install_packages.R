# Packages used across the pipeline (data construction + regressions).
# The tidyverse is loaded as individual components rather than the meta-package, so
# installation does not require system font libraries (freetype/harfbuzz/etc.).
install.packages(c(
  # tidyverse components
  "dplyr", "tidyr", "readr", "purrr", "stringr", "tibble", "ggplot2",
  # data + descriptives
  "haven", "wbstats", "skimr", "stargazer",
  "plm",               # two-way fixed-effects estimation + difference-GMM (pgmm)
  "clubSandwich",      # CR2 cluster-robust SEs w/ Satterthwaite dof (few-cluster fix, 24 countries)
  "car"                # joint Wald tests (structural-break interactions)
))