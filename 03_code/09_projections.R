# scripts/09_projections.R
# Run from the project root, after 06_regressions.R.
#
# Conditional long-run projections of GDP per capita paths — the final step in the
# thesis agreement ("the models will be used to generate simple conditional
# projections of long-run GDP paths"). Illustrative, not a forecasting exercise.
#
# Design (follows the thesis finding: slopes stable, level shifted):
# - Slopes: the FULL-SAMPLE baseline coefficients. The split-window models are not
#   iterated forward: with 10-12 year windows their convergence terms are dominated
#   by Nickell bias (bias ~ 1/T), which would anchor any projection to an
#   artificially tight steady state. Their role ends with the coefficient table.
# - Scenarios differ only in the COMMON ERA COMPONENT c_i: the country intercept
#   (country effect + era-average year effect), recovered as the window mean of
#   (observed growth - X*beta) under pre-crisis (1996-2007), post-crisis
#   (2010-2019, crisis trough excluded), and full-window (1996-2019) averages.
# - Launch: observed 2019 GDP per capita; investment share, log human capital and
#   population growth held at 2015-2019 country means; the convergence term
#   updates endogenously along the path.
# - Long-run logic: with stable slopes, an era-component gap dc shifts the
#   conditional steady-state income path by ~ dc/|b_conv| log points. The exhibit
#   shows what the post-2008 level shift implies for long-horizon paths when the
#   determinant relationship itself is held fixed.

library(dplyr); library(tidyr); library(purrr); library(tibble); library(ggplot2)
library(plm)

panel  <- readRDS("02_data/processed/panel_final.rds")
models <- readRDS("02_data/processed/models.rds")

horizon <- 2020:2045
b <- coef(models$base)

# Conditioning values: 2015-2019 country means of the slow-moving regressors,
# observed 2019 GDP per capita as the launch level.
cond <- panel |>
  filter(year >= 2015) |>
  group_by(countrycode) |>
  summarise(s = mean(inv_share), lnh = mean(ln_hc), n = mean(pop_growth_pwt),
            .groups = "drop")
launch <- panel |> filter(year == 2019) |> select(countrycode, gdppc)

# Country-level era component under the full-sample slopes: window mean of the
# part of growth the determinants do not explain (country effect + year effects).
era_component <- function(window) {
  panel |>
    filter(year %in% window) |>
    mutate(xb = b["ln_gdppc_lag"] * ln_gdppc_lag + b["inv_share"] * inv_share +
                b["ln_hc"] * ln_hc + b["pop_growth_pwt"] * pop_growth_pwt) |>
    group_by(countrycode) |>
    summarise(c_i = mean(gdppc_growth - xb), .groups = "drop")
}

project <- function(window, scenario) {
  st <- cond |>
    left_join(era_component(window), by = "countrycode") |>
    left_join(launch, by = "countrycode")
  map_dfr(seq_len(nrow(st)), function(i) {
    y <- st$gdppc[i]
    out <- numeric(length(horizon))
    for (k in seq_along(horizon)) {
      g <- b["ln_gdppc_lag"] * log(y) + b["inv_share"] * st$s[i] +
           b["ln_hc"] * st$lnh[i] + b["pop_growth_pwt"] * st$n[i] + st$c_i[i]
      y <- y * (1 + g)
      out[k] <- y
    }
    tibble(countrycode = st$countrycode[i], year = horizon,
           gdppc = out, scenario = scenario)
  })
}

proj <- bind_rows(
  project(1996:2007, "Pre-crisis era component (1996-2007)"),
  project(2010:2019, "Post-crisis era component (2010-2019)"),
  project(1996:2019, "Full-window era component (1996-2019)")
)

# Index each country's path to 2019 = 100, then average across countries.
proj_idx <- proj |>
  left_join(launch |> rename(gdppc_2019 = gdppc), by = "countrycode") |>
  mutate(index = 100 * gdppc / gdppc_2019)

mean_path <- proj_idx |>
  group_by(scenario, year) |>
  summarise(index = mean(index), .groups = "drop")

# Anchor every scenario at the observed 2019 = 100 point so the fan is readable.
anchor <- tibble(scenario = unique(mean_path$scenario), year = 2019, index = 100)
mean_path <- bind_rows(anchor, mean_path) |> arrange(scenario, year)

p <- ggplot(mean_path, aes(year, index, linetype = scenario)) +
  geom_line() +
  labs(title = "Conditional GDP per capita projections under stable slopes",
       subtitle = "Sample mean, 2019 = 100; full-sample coefficients, era component varied",
       x = NULL, y = "GDP per capita (index, 2019 = 100)", linetype = NULL) +
  theme_minimal() +
  theme(legend.position = "bottom", legend.direction = "vertical")
ggsave("05_figures/projections.png", p, width = 7, height = 4.8, dpi = 300)

# Headline numbers for the text.
cat("\n===== Projected mean GDP p.c. index (2019 = 100) =====\n")
summary_tbl <- mean_path |>
  filter(year %in% c(2030, 2045)) |>
  pivot_wider(names_from = year, values_from = index)
print(as.data.frame(summary_tbl), digits = 4)

at45 <- mean_path |> filter(year == max(horizon))
pre45  <- at45$index[grepl("^Pre",  at45$scenario)]
post45 <- at45$index[grepl("^Post", at45$scenario)]
cat(sprintf("\nPre vs post era-component gap at %d: %.1f%% (pre %.1f / post %.1f)\n",
            max(horizon), 100 * (pre45 / post45 - 1), pre45, post45))

# Era-component gap and implied steady-state level gap (sample means).
gap <- mean(era_component(1996:2007)$c_i) - mean(era_component(2010:2019)$c_i)
cat(sprintf("Mean era-component gap: %.4f (%.2fpp per year)\n", gap, 100 * gap))
cat(sprintf("Implied steady-state log-level gap: %.3f (= gap / |b_conv| = %.4f / %.4f)\n",
            gap / abs(b["ln_gdppc_lag"]), gap, abs(b["ln_gdppc_lag"])))

# ---------------------------------------------------------------------------
# Convergence scatter (one point per country): launch income vs projected growth.
#
# For each country the projected first-year (2020) growth rate under the full-window
# era component is g_i = b_conv*log(y2019) + b_s*s + b_h*lnh + b_n*n + c_i, the first
# iteration of project(). Plotting it against log launch income turns the projection
# into a Barro-type convergence diagram. The cross-country gradient is the
# UNCONDITIONAL comovement; the within-country convergence slope b_conv is the
# CONDITIONAL one. The vertical spread at a given income is country-effect (intercept)
# heterogeneity carried by c_i, which the pooled common slopes do not remove.
scatter_df <- cond |>
  left_join(era_component(1996:2019), by = "countrycode") |>
  left_join(launch, by = "countrycode") |>
  mutate(ln_y0 = log(gdppc),
         g0 = 100 * (b["ln_gdppc_lag"] * ln_y0 + b["inv_share"] * s +
                     b["ln_hc"] * lnh + b["pop_growth_pwt"] * n + c_i))

cross_fit  <- lm(g0 ~ ln_y0, data = scatter_df)
cross_b    <- coef(cross_fit)["ln_y0"]                 # cross-country (unconditional) slope, pp per log point
within_b   <- 100 * b["ln_gdppc_lag"]                  # within (conditional) convergence slope, pp per log point

ps <- ggplot(scatter_df, aes(ln_y0, g0)) +
  geom_smooth(method = "lm", se = FALSE, colour = "grey55",
              linetype = "dashed", linewidth = 0.5) +
  geom_point(colour = "grey25", size = 1.6) +
  geom_text(aes(label = countrycode), size = 2.5, vjust = -0.8, colour = "grey25") +
  labs(title = "Launch income and projected growth across countries",
       subtitle = "Full-sample slopes, full-window era component; one point per country",
       x = "Log GDP per capita, 2019 (launch year)",
       y = "Projected GDP per capita growth, first year (%)") +
  theme_minimal()
ggsave("05_figures/projection_convergence.png", ps, width = 7, height = 4.8, dpi = 300)

cat("\n===== Convergence scatter (full-window era component) =====\n")
print(as.data.frame(scatter_df |>
  transmute(countrycode, gdppc_2019 = round(gdppc, 1),
            ln_y0 = round(ln_y0, 3), g0_pct = round(g0, 2)) |>
  arrange(g0_pct)))
cat(sprintf("\nCross-country (unconditional) slope: %.3f pp per log point (R^2 = %.3f)\n",
            cross_b, summary(cross_fit)$r.squared))
cat(sprintf("Within (conditional) convergence slope: %.3f pp per log point\n", within_b))
cat(sprintf("Projected first-year growth range: %.2f%% (%s) to %.2f%% (%s); SD %.2f pp\n",
            min(scatter_df$g0), scatter_df$countrycode[which.min(scatter_df$g0)],
            max(scatter_df$g0), scatter_df$countrycode[which.max(scatter_df$g0)],
            sd(scatter_df$g0)))

saveRDS(list(paths = proj_idx, mean_path = mean_path, scatter = scatter_df),
        "02_data/processed/projections.rds")
cat("Wrote 05_figures/projections.png, 05_figures/projection_convergence.png, and 02_data/processed/projections.rds\n")
