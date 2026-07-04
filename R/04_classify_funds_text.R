source("R/00_setup.R")

aggressive_terms <- c(
  "akcj", "dynamicz", "agresywn", "pochodn", "wzrost",
  "rynek wschodz", "biotechnologi", "tech", "zmienno", "aktywn",
  "spekulacyjn", "innowacj", "globaln", "nowa gospodarka", "spolek",
  "fundusze akcyjne", "rynek akcji", "duzy potencjal", "wysoka stopa zwrotu"
)

conservative_terms <- c(
  "obligacj", "konserwatyw", "pieniez", "bezpiecz", "depozyt",
  "stabiln", "krotkoterminow", "ochrona kapitalu", "stale oprocentowanie",
  "instrumenty rynku pienieznego", "niska zmiennosc", "lokata",
  "zachowawcz", "plynno", "rentownosc", "zrownowazon", "portfel obronny",
  "wysoka jakosc kredytowa"
)

score_terms <- function(text, terms) {
  weights <- rep(1, length(terms))
  weights[grepl("agres|konserwaty", terms)] <- 2

  sum(stringr::str_count(text, terms) * weights)
}

classify_fund <- function(text) {
  if (is.na(text) || text == "") {
    return(data.frame(category = "uncertain", aggressive_score = 0, conservative_score = 0))
  }

  aggressive_score <- score_terms(text, aggressive_terms)
  conservative_score <- score_terms(text, conservative_terms)

  category <- dplyr::case_when(
    aggressive_score > conservative_score & aggressive_score > 0 ~ "aggressive",
    conservative_score > aggressive_score & conservative_score > 0 ~ "conservative",
    TRUE ~ "uncertain"
  )

  data.frame(
    category = category,
    aggressive_score = aggressive_score,
    conservative_score = conservative_score
  )
}

run_fund_text_classification <- function() {
  ensure_dirs()
  load_required_packages(c("dplyr", "readr", "stringr"))

  input_path <- project_path("data", "raw", "fund_classification.csv")
  funds_text <- readr::read_csv2(
    input_path,
    locale = readr::locale(encoding = "CP1250"),
    quote = "\"",
    show_col_types = FALSE
  )

  names(funds_text) <- trimws(names(funds_text))

  classified <- funds_text |>
    dplyr::mutate(
      text = paste(.data$`Nazwa funduszu`, .data$`Polityka inwestycyjna`) |>
        stringr::str_to_lower() |>
        iconv(from = "", to = "ASCII//TRANSLIT") |>
        stringr::str_replace_all("[[:punct:]]", " ")
    )

  scores <- dplyr::bind_rows(lapply(classified$text, classify_fund))
  output <- dplyr::bind_cols(classified, scores)

  write_table_csv(output, "fund_text_classification.csv")
  invisible(output)
}

if (sys.nframe() == 0) {
  run_fund_text_classification()
}
