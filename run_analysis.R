source("R/00_setup.R")
source("R/01_prepare_data.R")
source("R/02_descriptive_analysis.R")
source("R/03_models_backtesting.R")

main <- function() {
  prepare_fund_data()
  run_descriptive_analysis()
  run_model_backtesting()
}

main()
