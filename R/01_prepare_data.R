source("R/00_setup.R")

read_mst_fund <- function(file_path) {
  raw <- read.csv2(file_path, header = TRUE, sep = ",", dec = ".")

  dates <- as.Date(as.character(raw$X.DTYYYYMMDD.), format = "%Y%m%d")
  prices <- zoo::zoo(raw$X.OPEN., order.by = dates)
  returns <- diff(log(prices))

  list(prices = prices, returns = returns)
}

load_funds <- function(fund_map = funds) {
  flat_map <- c(fund_map$conservative, fund_map$aggressive)
  raw_dir <- project_path("data", "raw", "funds")

  lapply(flat_map, function(filename) {
    file_path <- file.path(raw_dir, filename)

    if (!file.exists(file_path)) {
      stop("Missing raw fund file: ", file_path, call. = FALSE)
    }

    read_mst_fund(file_path)
  })
}

build_equal_weight_portfolio <- function(fund_data, fund_names, start_date, end_date) {
  returns <- do.call(merge, lapply(fund_names, function(code) fund_data[[code]]$returns))
  weights <- rep(1 / length(fund_names), length(fund_names))

  portfolio <- zoo::zoo(returns %*% weights, order.by = zoo::index(returns))
  portfolio <- stats::window(stats::na.omit(portfolio), start = start_date, end = end_date)
  colnames(portfolio) <- "return"

  portfolio
}

build_price_frame <- function(fund_data, fund_map = funds) {
  fund_names <- c(names(fund_map$conservative), names(fund_map$aggressive))

  rows <- lapply(fund_names, function(code) {
    series <- fund_data[[code]]$prices

    if (is.null(series) || length(series) == 0) {
      return(NULL)
    }

    data.frame(
      date = zoo::index(series),
      price = as.numeric(zoo::coredata(series)),
      fund = code,
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows) |>
    dplyr::filter(.data$date >= analysis_window$start, .data$date <= analysis_window$end) |>
    dplyr::mutate(
      portfolio_type = dplyr::if_else(
        .data$fund %in% names(fund_map$conservative),
        "conservative",
        "aggressive"
      )
    )
}

build_return_frame <- function(fund_data, fund_map = funds) {
  fund_names <- c(names(fund_map$conservative), names(fund_map$aggressive))

  rows <- lapply(fund_names, function(code) {
    series <- fund_data[[code]]$returns

    if (is.null(series) || length(series) == 0) {
      return(NULL)
    }

    data.frame(
      date = zoo::index(series),
      return = as.numeric(zoo::coredata(series)),
      fund = code,
      stringsAsFactors = FALSE
    )
  })

  dplyr::bind_rows(rows) |>
    dplyr::filter(.data$date >= analysis_window$start, .data$date <= analysis_window$end) |>
    dplyr::mutate(
      portfolio_type = dplyr::if_else(
        .data$fund %in% names(fund_map$conservative),
        "conservative",
        "aggressive"
      )
    )
}

prepare_fund_data <- function() {
  ensure_dirs()
  load_required_packages()

  fund_data <- load_funds()
  conservative <- build_equal_weight_portfolio(
    fund_data,
    names(funds$conservative),
    analysis_window$start,
    analysis_window$end
  )
  aggressive <- build_equal_weight_portfolio(
    fund_data,
    names(funds$aggressive),
    analysis_window$start,
    analysis_window$end
  )

  portfolio_returns <- list(
    conservative = conservative,
    aggressive = aggressive
  )

  prepared <- list(
    fund_data = fund_data,
    prices = build_price_frame(fund_data),
    returns = build_return_frame(fund_data),
    portfolio_returns = portfolio_returns
  )

  saveRDS(prepared, project_path("data", "processed", "fund_data_prepared.rds"))
  invisible(prepared)
}

load_prepared_data <- function() {
  path <- project_path("data", "processed", "fund_data_prepared.rds")

  if (!file.exists(path)) {
    return(prepare_fund_data())
  }

  readRDS(path)
}
