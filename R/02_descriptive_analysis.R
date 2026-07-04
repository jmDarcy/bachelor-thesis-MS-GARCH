source("R/00_setup.R")
source("R/01_prepare_data.R")

portfolio_frame <- function(portfolios) {
  dplyr::bind_rows(
    data.frame(
      date = zoo::index(portfolios$conservative),
      return = as.numeric(portfolios$conservative),
      portfolio = "conservative"
    ),
    data.frame(
      date = zoo::index(portfolios$aggressive),
      return = as.numeric(portfolios$aggressive),
      portfolio = "aggressive"
    )
  )
}

descriptive_stats <- function(series) {
  x <- as.numeric(series)

  tibble::tibble(
    mean = mean(x, na.rm = TRUE),
    median = stats::median(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE),
    sd = stats::sd(x, na.rm = TRUE),
    skewness = moments::skewness(x, na.rm = TRUE),
    kurtosis = moments::kurtosis(x, na.rm = TRUE),
    jarque_bera = moments::jarque.test(x)$statistic
  )
}

stationarity_tests <- function(series) {
  x <- as.numeric(stats::na.omit(series))
  adf <- urca::ur.df(x, type = "drift", selectlags = "AIC")
  kpss <- tseries::kpss.test(x)

  tibble::tibble(
    adf_stat = adf@teststat[1],
    adf_critical_1pct = adf@cval[1, "1pct"],
    adf_critical_5pct = adf@cval[1, "5pct"],
    kpss_stat = unname(kpss$statistic),
    kpss_p_value = kpss$p.value
  )
}

diagnostic_tests <- function(series) {
  x <- as.numeric(stats::na.omit(series))
  arch <- FinTS::ArchTest(x, lags = 12)
  mcleod_li <- stats::Box.test(x^2, lag = 12, type = "Ljung-Box")
  ljung_box <- stats::Box.test(x, lag = 12, type = "Ljung-Box")

  tibble::tibble(
    arch_lm_stat = unname(arch$statistic),
    arch_lm_p_value = arch$p.value,
    mcleod_li_stat = unname(mcleod_li$statistic),
    mcleod_li_p_value = mcleod_li$p.value,
    ljung_box_stat = unname(ljung_box$statistic),
    ljung_box_p_value = ljung_box$p.value
  )
}

plot_fund_prices <- function(prices) {
  ggplot2::ggplot(prices, ggplot2::aes(x = .data$date, y = .data$price, color = .data$fund)) +
    ggplot2::geom_line(linewidth = 0.35) +
    ggplot2::facet_wrap(~ fund + portfolio_type, ncol = 2, scales = "free_y") +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "Unit prices of selected mutual funds",
      x = "Date",
      y = "Price"
    ) +
    ggplot2::theme(legend.position = "none")
}

plot_portfolio_returns <- function(portfolio_returns) {
  ggplot2::ggplot(portfolio_returns, ggplot2::aes(x = .data$date, y = .data$return, color = .data$portfolio)) +
    ggplot2::geom_line(linewidth = 0.35, alpha = 0.9) +
    ggplot2::facet_wrap(~ portfolio, ncol = 1, scales = "fixed") +
    ggplot2::theme_minimal() +
    ggplot2::labs(
      title = "Daily log returns of equal-weight portfolios",
      x = "Date",
      y = "Log return"
    ) +
    ggplot2::theme(legend.position = "none")
}

run_descriptive_analysis <- function() {
  ensure_dirs()
  load_required_packages()

  prepared <- load_prepared_data()
  portfolios <- prepared$portfolio_returns
  portfolio_returns <- portfolio_frame(portfolios)

  stats <- dplyr::bind_rows(
    descriptive_stats(portfolios$conservative) |> dplyr::mutate(portfolio = "conservative", .before = 1),
    descriptive_stats(portfolios$aggressive) |> dplyr::mutate(portfolio = "aggressive", .before = 1)
  )

  stationarity <- dplyr::bind_rows(
    stationarity_tests(portfolios$conservative) |> dplyr::mutate(portfolio = "conservative", .before = 1),
    stationarity_tests(portfolios$aggressive) |> dplyr::mutate(portfolio = "aggressive", .before = 1)
  )

  diagnostics <- dplyr::bind_rows(
    diagnostic_tests(portfolios$conservative) |> dplyr::mutate(portfolio = "conservative", .before = 1),
    diagnostic_tests(portfolios$aggressive) |> dplyr::mutate(portfolio = "aggressive", .before = 1)
  )

  write_table_csv(stats, "descriptive_statistics.csv")
  write_table_csv(stationarity, "stationarity_tests.csv")
  write_table_csv(diagnostics, "diagnostic_tests.csv")

  save_plot(plot_fund_prices(prepared$prices), "fund_prices.png", width = 10, height = 12)
  save_plot(plot_portfolio_returns(portfolio_returns), "portfolio_returns.png", width = 10, height = 7)

  invisible(list(
    descriptive_statistics = stats,
    stationarity_tests = stationarity,
    diagnostic_tests = diagnostics
  ))
}
