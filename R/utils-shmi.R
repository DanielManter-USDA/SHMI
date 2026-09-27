#' Read one sheet of an SHMI workbook (internal)
#'
#' Returns a zero-row tibble with `required_cols` if the sheet is missing or
#' empty, stops if a non-empty sheet lacks a required column, and drops rows
#' with no `MGT_combo`.
#' @keywords internal
#' @noRd
.safe_read <- function(path, sheet, required_cols, skip = 0, verbose = FALSE, ...) {

  # If sheet doesn't exist
  if (!sheet %in% readxl::excel_sheets(path)) {
    return(tibble::tibble(!!!stats::setNames(
      replicate(length(required_cols), logical(), simplify = FALSE),
      required_cols
    )))
  }

  # Try reading
  df <- readxl::read_xlsx(path, sheet = sheet, skip = skip, ...)
  df <- janitor::remove_empty(df, "rows")
  df <- janitor::remove_empty(df, "cols")

  # If empty, return zero-row tibble with correct columns
  if (nrow(df) == 0) {
    return(tibble::tibble(!!!stats::setNames(
      replicate(length(required_cols), logical(), simplify = FALSE),
      required_cols
    )))
  }

  # Ensure required columns exist
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(
      "Sheet '", sheet, "' is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  # Remove malformed rows with NA MGT_combo
  if ("MGT_combo" %in% names(df)) {
    bad <- sum(is.na(df$MGT_combo))
    if (bad > 0 && verbose) {
      message("Removed ", bad, " rows with NA MGT_combo from sheet '", sheet, "'.")
    }
    df <- df %>% dplyr::filter(!is.na(MGT_combo))
  }

  df
}

#' Parse SHMI date values (internal)
#'
#' Accepts `Date`, `POSIXct`, Excel serial numbers, and character dates in
#' year-month-day, month/day/year, or day/month/year order. Anything else
#' becomes `NA`.
#' @keywords internal
#' @noRd
.parse_shmi_date <- function(x) {

  vapply(
    x,
    FUN = function(val) {

      # 0. NA stays NA
      if (is.na(val)) {
        return(as.Date(NA))
      }

      # 1. Already a Date
      if (inherits(val, "Date")) {
        return(val)
      }

      # 2. POSIXct/POSIXt (readxl sometimes returns this)
      if (inherits(val, "POSIXt")) {
        return(as.Date(val))
      }

      # 3. Excel numeric or numeric-as-character
      if (is.numeric(val) || (is.character(val) && grepl("^[0-9]+$", val))) {
        num <- suppressWarnings(as.numeric(val))
        if (!is.na(num)) {
          return(as.Date(num, origin = "1899-12-30"))
        }
      }

      # 4. Character dates in many formats
      if (is.character(val)) {
        parsed <- suppressWarnings(
          lubridate::parse_date_time(
            val,
            orders = c(
              "Ymd", "Y-m-d",
              "mdY", "m/d/Y",
              "dmy", "d/m/Y"
            )
          )
        )
        if (!is.na(parsed)) {
          return(as.Date(parsed))
        }
      }

      # 5. Fallback
      return(as.Date(NA))
    },
    FUN.VALUE = as.Date(NA)
  )
}

#' Stop if a data frame lacks required columns (internal)
#' @keywords internal
#' @noRd
require_cols <- function(df, cols, sheet) {
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    stop(
      "Sheet '", sheet, "' is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
}
