# ----------------------------------------------------------------------
# Shared unit handling for per-area rates (yield, nitrogen)
# ----------------------------------------------------------------------

# Conversion factors to kg/ha, keyed by normalized unit
.rate_factors <- c(
  "kg/ha"    = 1,
  "lb/ha"    = 0.453592,
  "kg/acre"  = 1 / 0.404686,
  "lb/acre"  = 0.453592 / 0.404686,
  "t/ha"     = 1000,                  # metric tonne (also Mg/ha)
  "ton/acre" = 907.185 / 0.404686     # US short ton
)

# Standard test weights (lb per bushel, USDA legal weights), keyed by the
# crop name before any comma, lowercased ("Wheat, Winter" -> "wheat").
# Crops not listed are left unconverted rather than guessed.
.bushel_lb <- c(
  barley = 48, buckwheat = 48, canola = 50, corn = 56,
  flax = 56, flaxseed = 56, oats = 32, oat = 32, rye = 56,
  sorghum = 56, soybean = 60, soybeans = 60, wheat = 60
)

# Look up lb/bu for crop names; NA when no standard weight is known
.bushel_weight <- function(crop_name) {
  key <- tolower(trimws(sub(",.*$", "", as.character(crop_name))))
  unname(.bushel_lb[key])
}

#' Normalize per-area rate unit strings (internal)
#'
#' Maps the spellings used in the SHMI template dropdowns ("lbs/acre",
#' "kgs/hectare", "bushels/acre") and in free-text entries ("tons acre-1",
#' "Mg ha-1", "lbs acre-1 N", "kg per plot") to a small set of normalized
#' forms such as "lb/acre", "kg/ha", "t/ha", "bu/acre". Unrecognized units pass
#' through in simplified form so they can be reported.
#'
#' "Mg" is read as megagram (metric tonne), the usual meaning in agronomy.
#'
#' @keywords internal
#' @noRd
.normalize_rate_unit <- function(x) {
  u <- tolower(trimws(as.character(x)))
  u <- gsub("\\s+n$", "", u)                     # "lbs acre-1 N"
  u <- gsub("hectares?", "ha", u)
  u <- gsub("acres?", "acre", u)
  u <- gsub("\\s*(acre|ha)-1", "/\\1", u)        # "kg ha-1" -> "kg/ha"
  u <- gsub("\\s+per\\s+", "/", u)               # "kg per plot"
  u <- gsub("\\s+", "", u)
  u <- gsub("^kgs", "kg", u)
  u <- gsub("^lbs", "lb", u)
  u <- gsub("^tonnes", "t", u)
  u <- gsub("^tons", "ton", u)
  u <- gsub("^(bushels?|bus?)/", "bu/", u)
  u <- gsub("^mg/", "t/", u)                     # Mg (megagram) = tonne
  u
}

#' Convert per-area rates to kg/ha with a status for every value (internal)
#'
#' Values are never silently dropped: each gets a status explaining whether
#' and why it was converted.
#'
#' Bushels are converted only when `crop_name` is supplied and the crop has a
#' standard test weight in `.bushel_lb`. The result is at market moisture
#' (the basis of the test weight), not dry matter.
#'
#' @param value Numeric (or coercible) rates.
#' @param unit Unit strings.
#' @param crop_name Optional crop names, used only for bushel conversion.
#' @return A list with `value` (kg/ha, NA unless converted), `status`
#'   ("converted", "no_value", "missing_units", "bushels_not_converted",
#'   "unknown_units"), `unit_norm`, and `lb_per_bu` (test weight used, NA
#'   unless a bushel value was converted).
#' @keywords internal
#' @noRd
.convert_rate_kg_ha <- function(value, unit, crop_name = NULL) {
  v <- suppressWarnings(as.numeric(value))
  u <- .normalize_rate_unit(unit)
  f <- unname(.rate_factors[u])

  # Bushels: factor depends on the crop's test weight
  is_bu <- !is.na(u) & grepl("^bu/", u)
  lb_bu <- if (is.null(crop_name)) rep(NA_real_, length(v)) else .bushel_weight(crop_name)
  f_bu  <- dplyr::case_when(
    u == "bu/acre" ~ lb_bu * 0.453592 / 0.404686,
    u == "bu/ha"   ~ lb_bu * 0.453592,
    TRUE           ~ NA_real_
  )
  f <- ifelse(is_bu, f_bu, f)

  status <- dplyr::case_when(
    is.na(v)                 ~ "no_value",
    is.na(unit) | u == ""    ~ "missing_units",
    is_bu & is.na(f)         ~ "bushels_not_converted",
    is.na(f)                 ~ "unknown_units",
    TRUE                     ~ "converted"
  )

  list(
    value     = ifelse(status == "converted", v * f, NA_real_),
    status    = status,
    unit_norm = u,
    lb_per_bu = ifelse(status == "converted" & is_bu, lb_bu, NA_real_)
  )
}
