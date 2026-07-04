# Risk Measurement for Mutual Fund Portfolios with GARCH and Markov-Switching Models

This repository is the reproducible code companion to a bachelor's thesis on market-risk modelling for selected Polish mutual funds. The empirical part of the thesis compares a conservative and an aggressive equal-weight portfolio, estimates conditional volatility models, and evaluates one-day-ahead downside-risk forecasts with Value at Risk (VaR) and Expected Shortfall (ES).

The project was cleaned from a larger working directory and reorganized so that it can be reviewed, rerun, and pushed to GitHub without temporary files, duplicated scripts, binary model outputs, or local absolute paths.

## Thesis Context

The thesis focuses on the problem of measuring short-horizon investment risk when fund returns exhibit volatility clustering, heavy tails, and possible regime changes. Classical constant-volatility assumptions are not well suited to this setting, especially during periods of market stress. For that reason, the empirical workflow uses conditional heteroskedasticity models and regime-switching extensions.

The main empirical questions are:

- how the return dynamics differ between conservative and aggressive mutual fund portfolios;
- whether the analysed return series display stylized facts such as volatility clustering and non-normality;
- how GARCH-family and Markov-switching volatility models estimate tail risk;
- whether VaR and ES forecasts pass standard backtesting checks.

The analysis covers daily fund quotations from `2018-12-20` to `2023-12-20`. Two equal-weight portfolios are constructed:

- a conservative portfolio based on bond, money-market, and lower-risk funds;
- an aggressive portfolio based on equity, technology, gold, and dynamic-allocation funds.

## Methodology

The workflow follows four stages.

1. Data preparation

   Raw `.mst` files are imported, dates and prices are parsed, daily logarithmic returns are calculated, and the selected funds are aggregated into equal-weight conservative and aggressive portfolios.

2. Descriptive and diagnostic analysis

   The scripts calculate descriptive statistics, stationarity diagnostics, ARCH effects, Ljung-Box tests, McLeod-Li tests, and basic visualizations of prices and returns. This stage supports the thesis discussion on volatility clustering, non-normality, and the need for conditional volatility models.

3. Volatility modelling and tail-risk forecasting

   The main modelling script estimates eGARCH and MS-eGARCH specifications and produces rolling one-step-ahead Monte Carlo forecasts of VaR and ES at 1% and 5% risk levels.

4. Backtesting

   VaR forecasts are evaluated with Kupiec and Christoffersen tests. ES forecasts are evaluated with an Acerbi-Szekely style test statistic. Very short smoke-test runs return `NA` for tests that require more observations, while the full run is intended for final empirical results.

## Mathematical Formulation

Daily fund returns are computed as logarithmic returns:

$$
r_t = \log(P_t) - \log(P_{t-1}),
$$

where \(P_t\) is the fund price at day \(t\). For each portfolio, equal weights are used:

$$
r_{p,t} = \sum_{i=1}^{N} w_i r_{i,t}, \qquad w_i = \frac{1}{N}.
$$

The GARCH-family models describe returns through a conditional mean and conditional volatility:

$$
r_t = \mu_t + \varepsilon_t, \qquad
\varepsilon_t = \sigma_t z_t,
$$

where $\(z_t\)$ follows a standardized innovation distribution and $\(\sigma_t^2\)$ is the time-varying conditional variance. In the Markov-switching specification, parameters may depend on an unobserved regime variable \(S_t\), which allows volatility dynamics to differ across market states.

For a confidence tail level $\alpha$, the one-step-ahead Value at Risk is the conditional return quantile:

```math
\mathrm{VaR}_{t+1}^{(\alpha)}
=
\inf\left\{
x\in\mathbb{R}:
\mathbb{P}\left(r_{t+1}\leq x \mid \mathcal{F}_t\right)\geq \alpha
\right\}.
```

Expected Shortfall is the conditional mean loss beyond that quantile:

```math
\mathrm{ES}_{t+1}^{(\alpha)}
=
\mathbb{E}\left[
r_{t+1}
\mid
r_{t+1}\leq \mathrm{VaR}_{t+1}^{(\alpha)},\,
\mathcal{F}_t
\right].
```

## Repository Structure

```text
.
|-- R/
|   |-- 00_setup.R
|   |-- 01_prepare_data.R
|   |-- 02_descriptive_analysis.R
|   |-- 03_models_backtesting.R
|   `-- 04_classify_funds_text.R
|-- data/
|   |-- raw/
|   |   |-- fund_classification.csv
|   |   `-- funds/
|   `-- processed/
|-- output/
|   |-- figures/
|   |-- models/
|   `-- tables/
|-- run_analysis.R
|-- .gitignore
`-- README.md
```

## Main Scripts

- `R/00_setup.R` defines project paths, package requirements, fund groups, the analysis window, output helpers, and global settings.
- `R/01_prepare_data.R` imports fund quotation files, computes log returns, and builds equal-weight portfolio series.
- `R/02_descriptive_analysis.R` produces descriptive statistics, diagnostic tests, and exploratory figures.
- `R/03_models_backtesting.R` runs rolling eGARCH and MS-eGARCH VaR/ES forecasts and backtests them.
- `R/04_classify_funds_text.R` is an auxiliary NLP-style rule-based classifier for fund policy descriptions.
- `run_analysis.R` runs the main reproducible pipeline: data preparation, descriptive analysis, and model backtesting.

## Requirements

The project uses R 4.3+ and the following packages:

```r
c(
  "dplyr", "tidyr", "tibble", "readr", "stringr",
  "zoo", "xts", "ggplot2", "gridExtra", "patchwork",
  "moments", "tseries", "urca", "FinTS", "forecast",
  "rugarch", "MSGARCH", "PerformanceAnalytics", "xtable"
)
```

Install missing packages with:

```r
install.packages(c(
  "dplyr", "tidyr", "tibble", "readr", "stringr",
  "zoo", "xts", "ggplot2", "gridExtra", "patchwork",
  "moments", "tseries", "urca", "FinTS", "forecast",
  "rugarch", "MSGARCH", "PerformanceAnalytics", "xtable"
))
```

## How to Run

Run all main stages from the repository root:

```r
source("run_analysis.R")
```

The full rolling backtest can be computationally expensive because it repeatedly estimates GARCH and MS-eGARCH models and simulates Monte Carlo forecasts. Markov-switching model estimation in particular may take a long time. For a quick end-to-end smoke test that verifies whether the code executes, use:

```r
Sys.setenv(FAST_MODE = "true")
source("run_analysis.R")
```

For a controlled custom run:

```r
Sys.setenv(N_SIM = "1000", MAX_STEPS = "25")
source("run_analysis.R")
```

For the auxiliary fund-text classification:

```r
source("R/04_classify_funds_text.R")
run_fund_text_classification()
```

## Outputs

The scripts write reproducible outputs to:

- `output/tables/` for CSV tables with descriptive statistics, diagnostics, VaR/ES forecasts, and backtests;
- `output/figures/` for generated plots;
- `output/models/` for serialized model/backtest objects;
- `data/processed/` for prepared return data.

Generated outputs are ignored by Git because they can be recreated from the raw data and scripts. This keeps the repository focused on source code, input data, and documentation.

## Data Notes

The raw `.mst` files contain daily fund quotation data. The code expects the original column names used in the source files, especially:

- `X.DTYYYYMMDD.` for dates;
- `X.OPEN.` for prices.

The selected funds and their mapping to source files are defined in `R/00_setup.R`.

## Reproducibility Notes

- The code uses relative paths only; run it from the repository root.
- Randomness is controlled with `set.seed(121732)`.
- Full model results may vary slightly across R/package versions because numerical optimization and simulation are involved.
- Short smoke tests are intended only to verify that the pipeline executes, not to reproduce final thesis-level statistical conclusions.

## Validation Performed

The cleaned repository was checked with R 4.3.2 on Windows:

- all R files parse successfully;
- all required packages are installed;
- data preparation runs successfully;
- descriptive analysis runs successfully;
- text classification runs successfully;
- model backtesting executes successfully in smoke-test mode with `N_SIM=100` and `MAX_STEPS=1`.

The full default backtest is intentionally heavier because MS-eGARCH estimation is slow and should be run only when final empirical outputs are needed.
