# scripts/05_descriptives.R
# Run from the project root.
# tidyverse components (loaded individually to avoid the meta-package's
# system-font build dependencies; behaviour is identical)
library(dplyr); library(tidyr); library(readr); library(stringr)
library(purrr); library(tibble); library(ggplot2)

panel <- readRDS("02_data/processed/panel_final.rds")

# ── Summary statistics table (Pandoc markdown, with crossref caption) ──────────
desc_vars <- list(
  `GDP p.c. growth`    = panel$gdppc_growth,
  `Log GDP p.c. (lag)` = panel$ln_gdppc_lag,
  `Investment share`   = panel$inv_share,
  `Log human capital`  = panel$ln_hc,
  `Population growth`  = panel$pop_growth_pwt,
  `Employment growth`  = panel$emp_growth,
  `Post-2008 dummy`    = panel$post_2008,
  `Post-2010 dummy`    = panel$post_2010)

desc_row <- function(name, x) sprintf("| %s | %d | %.3f | %.3f | %.3f | %.3f |",
  name, sum(!is.na(x)), mean(x, na.rm = TRUE), sd(x, na.rm = TRUE),
  min(x, na.rm = TRUE), max(x, na.rm = TRUE))

desc_md <- c(
  "| Variable | N | Mean | SD | Min | Max |",
  "| --- | --- | --- | --- | --- | --- |",
  mapply(desc_row, names(desc_vars), desc_vars),
  "",
  ": Descriptive statistics over the estimation sample (1996--2019, 24 countries). {#tbl:desc}")
writeLines(desc_md, "06_tables/descriptives.md")
cat("Wrote 06_tables/descriptives.md\n")

# ── Pre/post-2008 descriptive panel (the headline level shift) ─────────────────
pp <- panel |>
  mutate(period = if_else(year >= 2008, "Post-2008", "Pre-2008")) |>
  group_by(period) |>
  summarise(
    g_m   = mean(gdppc_growth, na.rm = TRUE),   g_sd   = sd(gdppc_growth, na.rm = TRUE),
    inv_m = mean(inv_share, na.rm = TRUE),      inv_sd = sd(inv_share, na.rm = TRUE),
    hc_m  = mean(ln_hc, na.rm = TRUE),          hc_sd  = sd(ln_hc, na.rm = TRUE),
    n_m   = mean(pop_growth_pwt, na.rm = TRUE), n_sd   = sd(pop_growth_pwt, na.rm = TRUE),
    .groups = "drop") |>
  arrange(desc(period))    # Pre-2008 row first, Post-2008 second
f2 <- function(m, s) sprintf("%.3f (%.3f)", m, s)
pp_md <- c(
  "| Variable | Pre-2008 (1996--2007) | Post-2008 (2008--2019) |",
  "| --- | --- | --- |",
  sprintf("| GDP p.c. growth | %s | %s |",   f2(pp$g_m[1], pp$g_sd[1]),   f2(pp$g_m[2], pp$g_sd[2])),
  sprintf("| Investment share | %s | %s |",  f2(pp$inv_m[1], pp$inv_sd[1]), f2(pp$inv_m[2], pp$inv_sd[2])),
  sprintf("| Log human capital | %s | %s |", f2(pp$hc_m[1], pp$hc_sd[1]),  f2(pp$hc_m[2], pp$hc_sd[2])),
  sprintf("| Population growth | %s | %s |", f2(pp$n_m[1], pp$n_sd[1]),    f2(pp$n_m[2], pp$n_sd[2])),
  "",
  ": Sample means before and after 2008, standard deviations in parentheses. Mean GDP per capita growth falls from 2.5\\% to 0.6\\% per year while its dispersion widens. {#tbl:descpp}")
writeLines(pp_md, "06_tables/descriptives_prepost.md")
cat("Wrote 06_tables/descriptives_prepost.md\n")

# ── Panel balance check ────────────────────────────────────────────────────────
panel |>
  group_by(countrycode) |>
  summarise(
    n_obs         = n(),
    missing_gdppc = sum(is.na(gdppc_growth)),
    missing_hc    = sum(is.na(ln_hc)),
    missing_inv   = sum(is.na(inv_share))
  ) |>
  print(n = 30)

# ── Descriptive figures ───────────────────────────────────────────────────────

# (1) Mean GDP-per-capita growth over time, with the 2008 break marked.
yearly <- panel |>
  group_by(year) |>
  summarise(mean_growth = mean(gdppc_growth, na.rm = TRUE), .groups = "drop")

p_trend <- ggplot(yearly, aes(year, mean_growth)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_vline(xintercept = 2008, linetype = "dashed", colour = "grey50") +
  geom_line() + geom_point() +
  annotate("text", x = 2008, y = max(yearly$mean_growth), label = "2008",
           hjust = -0.1, size = 3, colour = "grey40") +
  labs(title = "Mean GDP per capita growth across OECD sample",
       x = NULL, y = "Mean annual growth") +
  theme_minimal()
ggsave("05_figures/growth_trend.png", p_trend, width = 7, height = 4, dpi = 300)

# (2) Pre- vs post-2008 growth distribution.
p_dist <- panel |>
  mutate(period = if_else(year >= 2008, "2008-2019", "1996-2007")) |>
  ggplot(aes(period, gdppc_growth)) +
  geom_hline(yintercept = 0, colour = "grey70") +
  geom_boxplot(outlier.alpha = 0.4, width = 0.5) +
  labs(title = "Growth distribution before vs after the crisis",
       x = NULL, y = "GDP per capita growth") +
  theme_minimal()
ggsave("05_figures/growth_prepost.png", p_dist, width = 6, height = 4, dpi = 300)

# (3) Per-country growth paths (appendix small-multiples).
p_country <- ggplot(panel, aes(year, gdppc_growth)) +
  geom_hline(yintercept = 0, colour = "grey80") +
  geom_vline(xintercept = 2008, linetype = "dashed", colour = "grey70") +
  geom_line() +
  facet_wrap(~ countrycode, ncol = 4, scales = "free_y") +
  labs(title = "GDP per capita growth by country, 1996-2019",
       x = NULL, y = "Growth") +
  theme_minimal(base_size = 8)
ggsave("05_figures/growth_by_country.png", p_country, width = 9, height = 11, dpi = 300)

cat("Wrote descriptive figures to 05_figures/\n")
