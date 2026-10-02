#' Validate prepared SHMI inputs
#'
#' Checks the list returned by [prepare_shmi_inputs()] before scoring.
#' [build_shmi()] calls this function automatically, passing the disturbance
#' method in use.
#'
#' @details
#' Errors: a required table is missing; `MGT_combo` is missing or `NA`;
#' required crop columns are missing; dates are not of class `Date`; a crop,
#' rotation, or animal period ends before it starts; or disturbance inputs do
#' not suit `dist_meth`. For `"EPA"`, every pass with `SD_mixeff > 0` needs
#' `SD_depth` and `SD_mixeff` must lie within 0-1.
#'
#' Warnings: for `"STIR"`, all non-zero `SD_mixeff` values are 1 or less,
#' which suggests EPA mixing proportions were entered instead of STIR values.
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()], containing
#'   at least `mgt`, `crop`, `rot_bounds`, `dist`, `amend`, and `animal`.
#' @param dist_meth Optional disturbance method, `"EPA"` or `"STIR"`. When
#'   supplied, method-specific disturbance checks are run.
#'
#' @return A list with `ok` (logical), `errors` and `warnings` (character
#'   vectors), and `summary` (a tibble with the numbers of fields, years,
#'   species, and mixtures, and whether fallow is present).
#'
#' @seealso [build_shmi()], [validate_excel_input()]
#'
#' @export
validate_shmi_input <- function(shmi_inputs, dist_meth = NULL) {

  errors   <- character()
  warnings <- character()

  # ---- 1. Required tables ----
  required_tables <- c(
    "mgt",
    "crop",
    "rot_bounds",
    "dist",
    "amend",
    "animal"
  )

  missing_tables <- setdiff(required_tables, names(shmi_inputs))
  if (length(missing_tables) > 0) {
    errors <- c(
      errors,
      paste("Missing required tables:", paste(missing_tables, collapse = ", "))
    )
    # If these are missing, further checks will likely error; bail early.
    return(list(ok = FALSE, errors = errors, warnings = warnings,
                summary = tibble::tibble()))
  }

  # ---- 2. Check MGT_combo presence and NAs ----
  for (tbl in required_tables) {
    x <- shmi_inputs[[tbl]]
    if (!"MGT_combo" %in% names(x)) {
      errors <- c(errors, paste0("Table '", tbl, "' is missing MGT_combo column"))
    } else if (any(is.na(x$MGT_combo))) {
      errors <- c(errors, paste0("Table '", tbl, "' contains NA MGT_combo values"))
    }
  }

  # ---- 3. Check crop structure ----
  ch <- shmi_inputs$crop
  required_crop_cols <- c("CD_name", "crop_start", "crop_end")
  missing_crop_cols  <- setdiff(required_crop_cols, names(ch))
  if (length(missing_crop_cols) > 0) {
    errors <- c(
      errors,
      paste("crop missing columns:",
            paste(missing_crop_cols, collapse = ", "))
    )
  } else {
    # date classes
    if (!inherits(ch$crop_start, "Date") || !inherits(ch$crop_end, "Date")) {
      errors <- c(errors, "crop$crop_start and crop_end must be Date")
    }
    # start <= end
    if (any(ch$crop_start > ch$crop_end, na.rm = TRUE)) {
      errors <- c(errors, "Some crop rows have crop_start > crop_end")
    }
  }

  # ---- 4. Check rotation boundaries ----
  rb <- shmi_inputs$rot_bounds
  if (!all(c("rot_start", "rot_end") %in% names(rb))) {
    errors <- c(errors, "rot_bounds must contain rot_start and rot_end")
  } else {
    if (!inherits(rb$rot_start, "Date") || !inherits(rb$rot_end, "Date")) {
      errors <- c(errors, "rot_bounds$rot_start and rot_end must be Date")
    }
    if (any(rb$rot_start > rb$rot_end, na.rm = TRUE)) {
      errors <- c(errors, "Some rotation boundaries have rot_start > rot_end")
    }
  }

  # ---- 5. Check dist date column ----
  dd <- shmi_inputs$dist
  if (!"SD_date" %in% names(dd)) {
    errors <- c(errors, "dist is missing 'SD_date' column")
  } else if (!inherits(dd$SD_date, "Date")) {
    errors <- c(errors, "dist$SD_date must be Date")
  }

  # ---- 5b. Method-specific disturbance checks ----
  if (!is.null(dist_meth)) {
    chk <- .check_dist_method(dd, dist_meth)
    errors   <- c(errors,   chk$errors)
    warnings <- c(warnings, chk$warnings)
  }

  # ---- 6. Check amend / animal date columns ----
  am <- shmi_inputs$amend
  if ("SA_date" %in% names(am) && !inherits(am$SA_date, "Date")) {
    errors <- c(errors, "amend$SA_date must be Date")
  }

  an <- shmi_inputs$animal
  animal_date_cols <- c("AD_start_date", "AD_end_date")
  if (!all(animal_date_cols %in% names(an))) {
    errors <- c(errors, "animal must contain AD_start_date and AD_end_date")
  } else {
    if (!inherits(an$AD_start_date, "Date") ||
        !inherits(an$AD_end_date, "Date")) {
      errors <- c(errors, "animal AD_start_date and AD_end_date must be Date")
    }
    if (any(an$AD_start_date > an$AD_end_date, na.rm = TRUE)) {
      errors <- c(errors, "Some animal windows have AD_start_date > AD_end_date")
    }
  }

  # ---- 7. Non-fatal diagnostics ----
  # fields
  n_fields <- length(unique(shmi_inputs$mgt$MGT_combo))

  # years from rotation bounds
  years <- unique(c(
    lubridate::year(shmi_inputs$rot_bounds$rot_start),
    lubridate::year(shmi_inputs$rot_bounds$rot_end)
  ))
  n_years <- length(years)

  # species and mixtures
  species_vec <- unique(ch$CD_name)
  n_species   <- length(species_vec)
  n_mixtures  <- sum(grepl("\\+", species_vec) | grepl("-species", species_vec))

  # fallow presence
  has_fallow <- any(tolower(ch$CD_name) == "fallow", na.rm = TRUE)

  summary <- tibble::tibble(
    fields       = n_fields,
    years        = n_years,
    species      = n_species,
    mixtures     = n_mixtures,
    has_fallow   = has_fallow
  )

  # ---- 8. Final output ----
  list(
    ok       = length(errors) == 0,
    errors   = errors,
    warnings = warnings,
    summary  = summary
  )
}


#' Method-specific disturbance checks (internal)
#'
#' Shared by `validate_shmi_input()` and `compute_disturbance()` so the rules
#' live in one place.
#'
#' EPA: every pass with `SD_mixeff > 0` needs an `SD_depth`, and `SD_mixeff`
#' must be a proportion between 0 and 1. Passes with `SD_mixeff == 0` contribute
#' nothing and do not need a depth.
#'
#' STIR: `SD_mixeff` holds STIR values. If every non-zero value is <= 1, the
#' column probably holds EPA mixing proportions instead, so a warning is issued.
#'
#' @param dist Disturbance table with `MGT_combo`, `SD_date`, `SD_mixeff`,
#'   and optionally `SD_depth`.
#' @param dist_meth `"EPA"` or `"STIR"`.
#' @return A list with character vectors `errors` and `warnings`.
#' @keywords internal
#' @noRd
.check_dist_method <- function(dist, dist_meth) {

  errors   <- character()
  warnings <- character()

  if (!dist_meth %in% c("EPA", "STIR")) {
    errors <- c(errors, paste0(
      "dist_meth must be 'EPA' or 'STIR', not '", dist_meth, "'."
    ))
    return(list(errors = errors, warnings = warnings))
  }

  if (is.null(dist) || nrow(dist) == 0) {
    return(list(errors = errors, warnings = warnings))
  }

  first_rows <- function(idx, n = 5) {
    ids <- unique(paste(dist$MGT_combo[idx], dist$SD_date[idx]))
    paste0(paste(utils::head(ids, n), collapse = "; "),
           if (length(ids) > n) paste0(" (+", length(ids) - n, " more)") else "")
  }
  num <- function(k) if (k %in% names(dist)) suppressWarnings(as.numeric(dist[[k]])) else rep(NA_real_, nrow(dist))
  mixeff <- num("SD_mixeff"); depth <- num("SD_depth")
  equip  <- if ("SD_equip" %in% names(dist)) !is.na(dist$SD_equip) & trimws(dist$SD_equip) != "" else rep(FALSE, nrow(dist))

  if (any(mixeff < 0, na.rm = TRUE)) errors <- c(errors, "SD_mixeff contains negative values.")
  if (any(depth < 0, na.rm = TRUE))  errors <- c(errors, "SD_depth contains negative values; depths are in inches.")

  if (dist_meth == "EPA") {
    # SD_mixeff and SD_depth are overrides of the implement's T-DISC values
    over <- !is.na(mixeff) & mixeff > 1
    if (any(over)) {
      errors <- c(errors, paste0(
        "SD_mixeff holds mixing efficiencies (0-1), but ", sum(over), " pass(es) exceed 1; ",
        "values like these look like STIR. Put STIR values in SD_stir (and use dist_meth = 'STIR' ",
        "to score with them), or leave SD_mixeff blank to use the implement's T-DISC value. ",
        "First affected: ", first_rows(over)))
    }
    unusable <- !equip & !(!is.na(mixeff) & !is.na(depth))
    if (any(unusable)) {
      errors <- c(errors, paste0(
        "dist_meth = 'EPA' needs, for every pass, an implement name (SD_equip) or both ",
        "SD_mixeff and SD_depth: ", sum(unusable), " pass(es) have neither. First affected: ",
        first_rows(unusable)))
    }
    deep <- !is.na(depth) & depth > 20
    if (any(deep)) {
      warnings <- c(warnings, paste0(
        sum(deep), " pass(es) have SD_depth > 20 inches; SD_depth is in inches, and depths are ",
        "capped at 30 cm (11.8 in). First affected: ", first_rows(deep)))
    }
  }

  if (dist_meth == "STIR") {
    stir <- .stir_values(dist)
    miss <- is.na(stir)
    if (any(miss)) {
      errors <- c(errors, paste0(
        "dist_meth = 'STIR' needs a STIR value (SD_stir) for every pass: ", sum(miss),
        " pass(es) have none. First affected: ", first_rows(miss)))
    }
    if (any(stir < 0, na.rm = TRUE)) errors <- c(errors, "SD_stir contains negative values.")
    active <- !is.na(stir) & stir > 0
    if (any(active) && all(stir[active] <= 1)) {
      warnings <- c(warnings, paste0(
        "dist_meth = 'STIR' but every non-zero STIR value is <= 1. These look like ",
        "mixing efficiencies rather than STIR values; check the disturbance method."))
    }
  }

  list(errors = errors, warnings = warnings)
}
