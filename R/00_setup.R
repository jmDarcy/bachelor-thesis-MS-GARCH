`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

options(xts.warn_dplyr_breaks_lag = FALSE)

PROJECT_ROOT <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)

project_path <- function(...) {
  file.path(PROJECT_ROOT, ...)
}

ensure_dirs <- function() {
  dirs <- c(
    project_path("data", "processed"),
    project_path("output", "figures"),
    project_path("output", "tables"),
    project_path("output", "models")
  )

  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
}

required_packages <- c(
  "dplyr", "tidyr", "tibble", "readr", "stringr",
  "zoo", "xts", "ggplot2", "gridExtra", "patchwork",
  "moments", "tseries", "urca", "FinTS", "forecast",
  "rugarch", "MSGARCH", "PerformanceAnalytics", "xtable"
)

load_required_packages <- function(packages = required_packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing) > 0) {
    stop(
      "Missing R packages: ",
      paste(missing, collapse = ", "),
      ". Install them before running the analysis.",
      call. = FALSE
    )
  }

  invisible(lapply(packages, library, character.only = TRUE))
}

save_plot <- function(plot, filename, width = 10, height = 6, dpi = 300) {
  ggplot2::ggsave(
    filename = project_path("output", "figures", filename),
    plot = plot,
    width = width,
    height = height,
    dpi = dpi
  )
}

write_table_csv <- function(data, filename) {
  readr::write_csv(data, project_path("output", "tables", filename))
}

funds <- list(
  conservative = c(
    IPOPEMA_K = "IPO082.mst",
    INVESTOR_K = "DWS037.mst",
    ALLIANZ_K = "ALL005.mst",
    NOBLE_K = "NOB001.mst",
    ALLIANZ_OBLIGACJI_ULTRA_K = "ALL038.mst"
  ),
  aggressive = c(
    PKO_TECH_A = "PKO027.mst",
    GOLDMAN_A = "ING027.mst",
    ALLIANZ_ZLO_A = "ALL033.mst",
    AGIO_A = "AGI044.mst",
    PKO_DYN_A = "PKO002.mst"
  )
)

analysis_window <- list(
  start = as.Date("2018-12-20"),
  end = as.Date("2023-12-20")
)

risk_levels <- c(0.01, 0.05)

set.seed(121732)
