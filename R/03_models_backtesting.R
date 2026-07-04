source("R/00_setup.R")
source("R/01_prepare_data.R")

garch_spec <- function(model, order = c(1, 1), arma_order = c(0, 0), distribution = "std") {
  rugarch::ugarchspec(
    variance.model = list(model = model, garchOrder = order),
    mean.model = list(armaOrder = arma_order, include.mean = TRUE),
    distribution.model = distribution
  )
}

fit_garch_models <- function(portfolios) {
  list(
    conservative_egarch = rugarch::ugarchfit(
      spec = garch_spec("eGARCH", order = c(1, 2), arma_order = c(3, 2), distribution = "sstd"),
      data = portfolios$conservative,
      solver = "hybrid"
    ),
    aggressive_egarch = rugarch::ugarchfit(
      spec = garch_spec("eGARCH", order = c(1, 2), arma_order = c(1, 0), distribution = "sstd"),
      data = portfolios$aggressive,
      solver = "hybrid"
    )
  )
}

fit_msgarch_models <- function(portfolios) {
  conservative_arma <- forecast::Arima(portfolios$conservative, order = c(3, 0, 2))
  aggressive_arma <- forecast::Arima(portfolios$aggressive, order = c(1, 0, 0))

  spec <- MSGARCH::CreateSpec(
    variance.spec = list(model = "eGARCH"),
    distribution.spec = list(distribution = "sstd"),
    switch.spec = list(K = 2)
  )

  list(
    conservative_msgarch = MSGARCH::FitML(spec = spec, data = stats::residuals(conservative_arma)),
    aggressive_msgarch = MSGARCH::FitML(spec = spec, data = stats::residuals(aggressive_arma)),
    msgarch_spec = spec
  )
}

simulate_garch_var_es <- function(fit, n_sim = 5000, levels = risk_levels) {
  simulation <- rugarch::ugarchsim(
    fit,
    n.sim = 1,
    m.sim = n_sim
  )

  simulated_returns <- as.numeric(rugarch::fitted(simulation))

  rows <- lapply(levels, function(alpha) {
    value_at_risk <- unname(stats::quantile(simulated_returns, probs = alpha, na.rm = TRUE))
    expected_shortfall <- mean(simulated_returns[simulated_returns <= value_at_risk], na.rm = TRUE)

    data.frame(alpha = alpha, VaR = value_at_risk, ES = expected_shortfall)
  })

  dplyr::bind_rows(rows)
}

simulate_msgarch_var_es <- function(fit, n_sim = 5000, levels = risk_levels) {
  draws <- tryCatch(
    MSGARCH::Sim(fit, nahead = 1, nburn = 0, nsim = n_sim)$draw,
    error = function(error) numeric(0)
  )

  draws <- as.numeric(draws)
  draws <- draws[is.finite(draws)]

  if (length(draws) < 10) {
    return(data.frame(alpha = levels, VaR = NA_real_, ES = NA_real_))
  }

  rows <- lapply(levels, function(alpha) {
    value_at_risk <- unname(stats::quantile(draws, probs = alpha, na.rm = TRUE))
    tail_draws <- draws[draws <= value_at_risk]

    data.frame(
      alpha = alpha,
      VaR = value_at_risk,
      ES = if (length(tail_draws) == 0) NA_real_ else mean(tail_draws, na.rm = TRUE)
    )
  })

  dplyr::bind_rows(rows)
}

rolling_backtest_garch <- function(returns, spec, window_ratio = 0.8, n_sim = 5000,
                                   levels = risk_levels, max_steps = Inf,
                                   solver = "hybrid") {
  n <- length(returns)
  window_size <- floor(window_ratio * n)
  test_size <- min(n - window_size, max_steps)
  dates <- zoo::index(returns)[(window_size + 1):(window_size + test_size)]

  forecasts <- vector("list", test_size)

  for (i in seq_len(test_size)) {
    train <- returns[i:(i + window_size - 1)]
    fit <- rugarch::ugarchfit(spec = spec, data = train, solver = solver)
    metrics <- simulate_garch_var_es(fit, n_sim = n_sim, levels = levels)
    metrics$date <- dates[i]
    metrics$realized_return <- as.numeric(returns[i + window_size])
    forecasts[[i]] <- metrics
  }

  dplyr::bind_rows(forecasts)
}

rolling_backtest_msgarch <- function(returns, spec, window_ratio = 0.8, n_sim = 5000,
                                     levels = risk_levels, max_steps = Inf) {
  n <- length(returns)
  window_size <- floor(window_ratio * n)
  test_size <- min(n - window_size, max_steps)
  dates <- zoo::index(returns)[(window_size + 1):(window_size + test_size)]

  forecasts <- vector("list", test_size)

  for (i in seq_len(test_size)) {
    train <- as.numeric(returns[i:(i + window_size - 1)])
    fit <- MSGARCH::FitML(spec = spec, data = train)
    metrics <- simulate_msgarch_var_es(fit, n_sim = n_sim, levels = levels)
    metrics$date <- dates[i]
    metrics$realized_return <- as.numeric(returns[i + window_size])
    forecasts[[i]] <- metrics
  }

  dplyr::bind_rows(forecasts)
}

backtest_var <- function(results) {
  rows <- split(results, list(results$model, results$portfolio, results$alpha), drop = TRUE)

  dplyr::bind_rows(lapply(rows, function(data) {
    model <- unique(data$model)
    portfolio <- unique(data$portfolio)
    alpha <- unique(data$alpha)

    data <- data[stats::complete.cases(data$realized_return, data$VaR), ]

    if (nrow(data) < 2 || sum(data$realized_return < data$VaR) == 0) {
      return(data.frame(
        model = model,
        portfolio = portfolio,
        alpha = alpha,
        violations = sum(data$realized_return < data$VaR),
        kupiec_p_value = NA_real_,
        christoffersen_p_value = NA_real_
      ))
    }

    test <- rugarch::VaRTest(
      alpha = unique(data$alpha),
      actual = data$realized_return,
      VaR = data$VaR
    )

    data.frame(
      model = model,
      portfolio = portfolio,
      alpha = alpha,
      violations = sum(data$realized_return < data$VaR),
      kupiec_p_value = test$uc.LRp,
      christoffersen_p_value = test$cc.LRp
    )
  }))
}

backtest_es_acerbi_szekely <- function(results) {
  rows <- split(results, list(results$model, results$portfolio, results$alpha), drop = TRUE)

  dplyr::bind_rows(lapply(rows, function(data) {
    model <- unique(data$model)
    portfolio <- unique(data$portfolio)
    alpha <- unique(data$alpha)

    data <- data[stats::complete.cases(data$realized_return, data$VaR, data$ES), ]

    if (nrow(data) < 2) {
      return(data.frame(
        model = model,
        portfolio = portfolio,
        alpha = alpha,
        acerbi_szekely_stat = NA_real_,
        acerbi_szekely_p_value = NA_real_
      ))
    }

    exceedance <- as.numeric(data$realized_return <= data$VaR)
    statistic_series <- exceedance * data$realized_return / (alpha * data$ES) +
      data$VaR / data$ES - 1

    test_stat <- sqrt(length(statistic_series)) *
      mean(statistic_series, na.rm = TRUE) /
      stats::sd(statistic_series, na.rm = TRUE)

    if (!is.finite(test_stat)) {
      test_stat <- NA_real_
    }

    data.frame(
      model = model,
      portfolio = portfolio,
      alpha = alpha,
      acerbi_szekely_stat = test_stat,
      acerbi_szekely_p_value = 1 - stats::pnorm(test_stat)
    )
  }))
}

run_model_backtesting <- function() {
  ensure_dirs()
  load_required_packages()

  prepared <- load_prepared_data()
  portfolios <- prepared$portfolio_returns

  n_sim <- as.integer(Sys.getenv("N_SIM", "5000"))
  max_steps <- as.integer(Sys.getenv("MAX_STEPS", "248"))

  if (tolower(Sys.getenv("FAST_MODE", "false")) == "true") {
    n_sim <- min(n_sim, 100)
    max_steps <- min(max_steps, 1)
  }

  garch_specs <- list(
    conservative = garch_spec("eGARCH", order = c(1, 2), arma_order = c(3, 2), distribution = "sstd"),
    aggressive = garch_spec("eGARCH", order = c(1, 2), arma_order = c(1, 0), distribution = "sstd")
  )

  msgarch_spec <- MSGARCH::CreateSpec(
    variance.spec = list(model = "eGARCH"),
    distribution.spec = list(distribution = "sstd"),
    switch.spec = list(K = 2)
  )

  results <- dplyr::bind_rows(
    rolling_backtest_garch(portfolios$conservative, garch_specs$conservative, n_sim = n_sim, max_steps = max_steps) |>
      dplyr::mutate(model = "eGARCH", portfolio = "conservative", .before = 1),
    rolling_backtest_garch(portfolios$aggressive, garch_specs$aggressive, n_sim = n_sim, max_steps = max_steps) |>
      dplyr::mutate(model = "eGARCH", portfolio = "aggressive", .before = 1),
    rolling_backtest_msgarch(portfolios$conservative, msgarch_spec, n_sim = n_sim, max_steps = max_steps) |>
      dplyr::mutate(model = "MS-eGARCH", portfolio = "conservative", .before = 1),
    rolling_backtest_msgarch(portfolios$aggressive, msgarch_spec, n_sim = n_sim, max_steps = max_steps) |>
      dplyr::mutate(model = "MS-eGARCH", portfolio = "aggressive", .before = 1)
  )

  tests <- backtest_var(results)
  es_tests <- backtest_es_acerbi_szekely(results)

  write_table_csv(results, "rolling_var_es.csv")
  write_table_csv(tests, "var_backtests.csv")
  write_table_csv(es_tests, "es_acerbi_szekely_tests.csv")
  saveRDS(results, project_path("output", "models", "rolling_var_es.rds"))

  invisible(list(results = results, var_tests = tests, es_tests = es_tests))
}
