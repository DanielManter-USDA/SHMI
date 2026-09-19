#' Prepare and Validate SHMI Input Data from an Excel Workbook
#'
#' Reads, validates, harmonizes, and expands all input sheets required to
#' compute the Soil Health Management Index (SHMI). This function is the
#' official entry point for SHMI data preparation and produces a standardized
#' list of rotation‑scale objects used directly by \code{build_shmi()}.
#'
#' ## Overview
#'
#' The function performs:
#' \itemize{
#'   \item robust Excel ingestion with sheet‑level validation
#'   \item management‑unit filtering
#'   \item biological validation of crop chronology (annual/perennial rules)
#'   \item mixture‑aware harmonization of crop windows
#'   \item construction of rotation bounds (start/end dates and rotation years)
#'   \item assembly of disturbance, amendment, and animal event tables
#'   \item optional extraction of yield and nitrogen‑rate data
#'   \item override‑aware clipping of all event types
#' }
#'
#' The result is a clean, rotation‑scale dataset suitable for SHMI pillar
#' computation: cover, diversity, inverse disturbance, and organic inputs.
#'
#'
#' ## Required workbook structure
#'
#' The Excel file must contain the standard SHMI sheets:
#'
#' \itemize{
#'   \item \code{Mgt_Unit}
#'   \item \code{Crop_Diversity}
#'   \item \code{Soil_Disturbance}
#'   \item \code{Amendment_Diversity}
#'   \item \code{Animal_Diversity}
#' }
#'
#' Sheets may be empty; empty sheets are safely ignored.
#'
#'
#' ## Date overrides
#'
#' If \code{start_date_override} or \code{end_date_override} are supplied,
#' all event types (crop, disturbance, amendment, animal, yield, N‑rate)
#' occurring outside the override window are removed, and rotation bounds are
#' clipped accordingly.
#'
#'
#' ## Crop harmonization
#'
#' Crop windows are validated for biological realism:
#'
#' \itemize{
#'   \item annual crops must terminate within the same year
#'   \item perennials may span years but must follow valid chronology
#'   \item mixtures are collapsed to event‑level windows (min start, max end)
#' }
#'
#' The returned \code{crop} table contains one row per species with harmonized
#' start/end dates suitable for cover and diversity scoring.
#'
#'
#' ## Disturbance, amendments, and animals
#'
#' Disturbance events are returned in EPA/STIR‑ready format:
#'
#' \itemize{
#'   \item \code{SD_date}
#'   \item \code{SD_mixeff}
#'   \item \code{SD_depth}
#' }
#'
#' Amendment and animal events are clipped by overrides and returned in
#' rotation‑scale format for \code{compute_orginput()}.
#'
#'
#' ## Optional yield and nitrogen‑rate extraction
#'
#' If enabled:
#'
#' \itemize{
#'   \item Yield is extracted per crop event, unit‑standardized to kg/ha,
#'         and clipped by overrides.
#'   \item Nitrogen rate is extracted from amendment events, converted to
#'         kg N/ha, summarized per \code{MGT_combo × year}, and clipped by
#'         overrides.
#' }
#'
#' Missing values are retained as \code{NA}.
#'
#'
#' ## Front‑end validation
#'
#' The function automatically runs \code{validate_excel_input()} to check:
#'
#' \itemize{
#'   \item required sheets and columns
#'   \item valid date formats
#'   \item consistent \code{MGT_combo} values
#'   \item malformed entries
#' }
#'
#' If validation fails, execution stops with clear, actionable error messages.
#'
#'
#' @param path Path to the SHMI Excel workbook.
#'
#' @param exclude Optional character vector of \code{MGT_combo} identifiers to
#'   exclude from processing.
#'
#' @param verbose Logical; if \code{TRUE}, prints progress messages.
#'
#' @param start_date_override Optional \code{Date} or date‑coercible value.
#'
#' @param end_date_override Optional \code{Date} or date‑coercible value.
#'
#' @param calc_yield Logical; if \code{TRUE}, extract and standardize yield.
#'
#' @param calc_n_rate Logical; if \code{TRUE}, extract and standardize N‑rate.
#'
#'
#' @return A named list containing:
#' \describe{
#'   \item{\code{rot_bounds}}{Rotation start/end dates and rotation years.}
#'   \item{\code{crop}}{Mixture‑aware crop windows (one row per species).}
#'   \item{\code{dist}}{Disturbance event table (EPA/STIR‑ready).}
#'   \item{\code{amend}}{Amendment event table.}
#'   \item{\code{animal}}{Animal event table.}
#'   \item{\code{mgt}}{Management‑unit metadata.}
#'   \item{\code{yield}}{Optional crop‑event‑level yield table (kg/ha).}
#'   \item{\code{n_rate}}{Optional year‑level nitrogen‑rate table (kg N/ha).}
#' }
#'
#' @section Error Handling:
#' The function stops with informative errors if:
#' \itemize{
#'   \item required sheets or columns are missing
#'   \item crop chronology is biologically impossible
#'   \item date overrides produce empty rotations
#' }
#'
#' @seealso
#'   \code{\link{build_shmi}} for computing SHMI scores from prepared inputs.
#'
#' @export
prepare_shmi_inputs <- function(path,
                                exclude = NULL,
                                verbose = TRUE,
                                rot_calc = c("calendar", "farmer"),
                                start_date_override = NULL,
                                end_date_override   = NULL,
                                end_sample_date = FALSE,
                                calc_yield  = FALSE,
                                calc_n_rate = FALSE) {

  rot_calc <- match.arg(rot_calc)

  # ------------------------------------------------------------
  # 1. Validate inputs
  # ------------------------------------------------------------
  cli::cli_progress_step("Validating inputs...")

  val <- validate_excel_input(path, verbose)

  if (!val$ok) {
    message("❌ Excel input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run prepare_shmi_inputs().")
  }

  if (length(val$warnings) > 0) {
    message("\nWarnings:")
    message(paste0(" - ", val$warnings, collapse = "\n"))
  }

  if (!is.null(start_date_override)) {
    start_date_override <- as.Date(start_date_override)
    if (is.na(start_date_override)) {
      stop("start_date_override must be a valid date (YYYY-MM-DD).", call. = FALSE)
    }
  }

  if (!is.null(end_date_override)) {
    end_date_override <- as.Date(end_date_override)
    if (is.na(end_date_override)) {
      stop("end_date_override must be a valid date (YYYY-MM-DD).", call. = FALSE)
    }
  }

  # ------------------------------------------------------------
  # 2. Read MGT
  # ------------------------------------------------------------
  cli::cli_progress_step("Reading Excel file...")

  mgt <- .safe_read(
    path,
    sheet = "Mgt_Unit",
    required_cols = c("MGT_combo", "MGT_study", "MGT_field", "MGT_trt"),
    skip = 3,
    verbose = verbose
  ) %>%
    dplyr::select(dplyr::any_of(c(
      "user_name", "MGT_combo", "MGT_study", "MGT_farm",
      "MGT_field", "MGT_trt", "MGT_sample_date"
    ))) %>%
    janitor::remove_empty("rows") %>%
    dplyr::filter(!(MGT_combo %in% exclude))

  if (end_sample_date) {
    mgt_dates <- mgt %>%
      select(MGT_combo, MGT_sample_date) %>%
      mutate(MGT_sample_date = as.Date(MGT_sample_date))
  }

  # ------------------------------------------------------------
  # 3. Read Crop_Diversity
  # ------------------------------------------------------------
  crop <- .safe_read(
    path,
    sheet = "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_plant_date", "CD_term_date"),
    skip = 3,
    verbose = verbose
  ) %>%
    dplyr::filter(!(MGT_combo %in% exclude))

  if (!"CD_harv_date" %in% names(crop)) crop$CD_harv_date <- NA
  if (!"CD_cat" %in% names(crop))       crop$CD_cat       <- NA_character_

  crop <- crop %>%
    dplyr::mutate(
      CD_plant_date = as.Date(unname(.parse_shmi_date(CD_plant_date))),
      CD_harv_date  = as.Date(unname(.parse_shmi_date(CD_harv_date))),
      CD_term_date  = as.Date(unname(.parse_shmi_date(CD_term_date)))
    )

  # ------------------------------------------------------------
  # 4. Read Soil_Disturbance
  # ------------------------------------------------------------
  dist <- .safe_read(
    path,
    sheet = "Soil_Disturbance",
    required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
    skip = 3,
    verbose = verbose
  ) %>%
    dplyr::filter(!(MGT_combo %in% exclude)) %>%
    dplyr::mutate(SD_date = as.Date(unname(.parse_shmi_date(SD_date))))

  # ------------------------------------------------------------
  # 5. Read Soil_Amendments
  # ------------------------------------------------------------
  amend <- .safe_read(
    path,
    sheet = "Soil_Amendments",
    required_cols = NULL,
    skip = 3,
    verbose = verbose
  )

  if (is.null(amend) || !("SA_date" %in% names(amend)) ||
      all(is.na(.parse_shmi_date(amend$SA_date)))) {

    amend <- tibble::tibble(
      MGT_combo = character(),
      SA_date   = as.Date(character()),
      SA_cat    = character(),
      SA_N      = numeric()
    )

  } else {

    amend <- amend %>%
      dplyr::mutate(
        SA_date = as.Date(unname(.parse_shmi_date(SA_date)))
      ) %>%
      dplyr::filter(!(MGT_combo %in% exclude))
  }

  # ------------------------------------------------------------
  # 6. Read Animal_Diversity
  # ------------------------------------------------------------
  animal <- .safe_read(
    path,
    sheet = "Animal_Diversity",
    required_cols = NULL,
    skip = 3,
    verbose = verbose
  )

  if (is.null(animal) ||
      !all(c("AD_start_date", "AD_end_date") %in% names(animal)) ||
      (
        all(is.na(.parse_shmi_date(animal$AD_start_date))) &&
        all(is.na(.parse_shmi_date(animal$AD_end_date)))
      )) {

    animal <- tibble::tibble(
      MGT_combo     = character(),
      AD_start_date = as.Date(character()),
      AD_end_date   = as.Date(character()),
      AD_type       = character()
    )

  } else {

    animal <- animal %>%
      dplyr::mutate(
        AD_start_date = as.Date(unname(.parse_shmi_date(AD_start_date))),
        AD_end_date   = as.Date(unname(.parse_shmi_date(AD_end_date)))
      ) %>%
      dplyr::filter(!(MGT_combo %in% exclude))
  }

  # ------------------------------------------------------------
  # 7. Infer next planting (for crop_end logic)
  # ------------------------------------------------------------
  safe_min_date <- function(x) {
    x2 <- x[!is.na(x)]
    if (length(x2) == 0) return(as.Date(NA))
    as.Date(min(x2))
  }

  seq_dates <- crop %>%
    dplyr::group_by(MGT_combo, CD_seq_num) %>%
    dplyr::summarize(
      seq_plant = safe_min_date(CD_plant_date),
      .groups   = "drop"
    ) %>%
    dplyr::arrange(MGT_combo, CD_seq_num) %>%
    dplyr::group_by(MGT_combo) %>%
    dplyr::mutate(next_seq_plant = dplyr::lead(seq_plant)) %>%
    dplyr::ungroup()

  crop <- crop %>%
    dplyr::left_join(seq_dates, by = c("MGT_combo", "CD_seq_num")) %>%
    dplyr::mutate(next_plant = next_seq_plant)

  # ------------------------------------------------------------
  # 8. Category harmonization (Annual / Perennial)
  # ------------------------------------------------------------
  crop <- crop %>%
    dplyr::mutate(
      CD_cat = dplyr::case_when(
        CD_cat %in% c("annual", "cash", "cover", "fallow", "Cash", "Cover", "Fallow") ~ "Annual",
        CD_cat %in% c("perennial", "woody perennial") ~ "Perennial",
        TRUE ~ CD_cat
      )
    )

  # ------------------------------------------------------------
  # 9. Compute rotation bounds from raw events (no overrides yet)
  # ------------------------------------------------------------
  cli::cli_progress_step("Computing rotation bounds...")

  clean_df <- function(df, date_cols) {
    if (is.null(df)) return(NULL)
    if (nrow(df) == 0) return(NULL)
    if (!"MGT_combo" %in% names(df)) return(NULL)

    df <- df %>% dplyr::filter(!is.na(MGT_combo))
    df <- df %>%
      dplyr::filter(rowSums(!is.na(dplyr::across(dplyr::all_of(date_cols)))) > 0)

    if (nrow(df) == 0) return(NULL)
    df
  }

  crop_h   <- clean_df(crop,   c("CD_plant_date", "CD_harv_date", "CD_term_date"))
  dist_h   <- clean_df(dist,   c("SD_date"))
  amend_h  <- clean_df(amend,  c("SA_date"))
  animal_h <- clean_df(animal, c("AD_start_date", "AD_end_date"))

  summarize_bounds <- function(df, start_cols, end_cols) {
    df %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(
        start = {
          s <- pmin(!!!rlang::syms(start_cols), na.rm = TRUE)
          s[is.infinite(s)] <- NA
          if (all(is.na(s))) NA else min(s, na.rm = TRUE)
        },
        end = {
          e <- pmax(!!!rlang::syms(end_cols), na.rm = TRUE)
          e[is.infinite(e)] <- NA
          if (all(is.na(e))) NA else max(e, na.rm = TRUE)
        },
        .groups = "drop"
      )
  }

  df_list <- list()

  if (!is.null(crop_h)) {
    df_list[[length(df_list)+1]] <- summarize_bounds(
      crop_h,
      start_cols = c("CD_plant_date", "CD_harv_date", "CD_term_date"),
      end_cols   = c("CD_harv_date", "CD_term_date")
    )
  }

  if (!is.null(dist_h)) {
    df_list[[length(df_list)+1]] <- summarize_bounds(
      dist_h,
      start_cols = "SD_date",
      end_cols   = "SD_date"
    )
  }

  if (!is.null(amend_h)) {
    df_list[[length(df_list)+1]] <- summarize_bounds(
      amend_h,
      start_cols = "SA_date",
      end_cols   = "SA_date"
    )
  }

  if (!is.null(animal_h)) {
    df_list[[length(df_list)+1]] <- summarize_bounds(
      animal_h,
      start_cols = "AD_start_date",
      end_cols   = "AD_end_date"
    )
  }

  df_all <- dplyr::bind_rows(df_list)

  if (end_sample_date) {
    df_all <- df_all %>%
      dplyr::left_join(
        mgt_dates %>%
          dplyr::group_by(MGT_combo) %>%
          dplyr::summarize(MGT_sample_date = max(MGT_sample_date), .groups = "drop"),
        by = "MGT_combo"
      )
  }

  # base bounds (before overrides)
  if (rot_calc == "calendar") {
    rot_bounds <- df_all %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(
        yr_min = min(lubridate::year(start), na.rm = TRUE),
        yr_max = max(lubridate::year(end),   na.rm = TRUE),
        rot_start_default = as.Date(paste0(yr_min, "-01-01")),
        rot_end_default   = as.Date(paste0(yr_max, "-12-31")),
        rot_start = rot_start_default,
        rot_end   = if (end_sample_date)
          as.Date(max(MGT_sample_date))
        else
          rot_end_default,
        .groups = "drop"
      )
  } else {
    rot_bounds <- df_all %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(
        rot_start_default = min(start, na.rm = TRUE),
        rot_end_default   = max(end,   na.rm = TRUE),
        rot_start = rot_start_default,
        rot_end   = if (end_sample_date)
          as.Date(max(MGT_sample_date))
        else
          rot_end_default,
        .groups = "drop"
      )
  }

  # ------------------------------------------------------------
  # Remove rotations whose activity is entirely outside override window
  # ------------------------------------------------------------
  if (!is.null(start_date_override) || !is.null(end_date_override)) {

    S <- as.Date(start_date_override)
    E <- as.Date(end_date_override)

    rot_bounds <- rot_bounds %>%
      filter(
        # keep only rotations that overlap the override window
        rot_end_default   >= S & rot_start_default <= E
      )

    # drop from all tables
    valid_combos <- rot_bounds$MGT_combo

    mgt    <- mgt    %>% filter(MGT_combo %in% valid_combos)
    crop   <- crop   %>% filter(MGT_combo %in% valid_combos)
    dist   <- dist   %>% filter(MGT_combo %in% valid_combos)
    amend  <- amend  %>% filter(MGT_combo %in% valid_combos)
    animal <- animal %>% filter(MGT_combo %in% valid_combos)
  }

  # apply date overrides to bounds
  if (!is.null(start_date_override)) {
    rot_bounds <- rot_bounds %>%
      dplyr::mutate(rot_start = as.Date(start_date_override))
  }
  if (!is.null(end_date_override)) {
    rot_bounds <- rot_bounds %>%
      dplyr::mutate(rot_end = as.Date(end_date_override))
  }

  rot_bounds <- rot_bounds %>%
    dplyr::mutate(
      rot_start_yr = lubridate::year(as.Date(rot_start)),
      rot_end_yr   = lubridate::year(as.Date(rot_end))
    )

  # ------------------------------------------------------------
  # 10. Harmonize crop windows (using rot_bounds)
  # ------------------------------------------------------------
  crop <- crop %>%
    dplyr::left_join(rot_bounds, by = "MGT_combo") %>%
    dplyr::group_by(MGT_combo, CD_seq_num) %>%
    dplyr::mutate(
      plant_min_raw = suppressWarnings(min(CD_plant_date, na.rm = TRUE)),
      plant_min_raw = ifelse(is.infinite(plant_min_raw), NA, plant_min_raw),
      plant_min     = as.Date(plant_min_raw),

      crop_start = dplyr::case_when(
        !is.na(plant_min) ~ plant_min,
        CD_seq_num == 1   ~ rot_start,
        TRUE              ~ rot_start
      ),

      harv_min_raw = suppressWarnings(min(CD_harv_date, na.rm = TRUE)),
      term_min_raw = suppressWarnings(min(CD_term_date, na.rm = TRUE)),
      next_min_raw = suppressWarnings(min(next_plant,   na.rm = TRUE)),

      harv_min_raw = ifelse(is.infinite(harv_min_raw), NA, harv_min_raw),
      term_min_raw = ifelse(is.infinite(term_min_raw), NA, term_min_raw),
      next_min_raw = ifelse(is.infinite(next_min_raw), NA, next_min_raw),

      harv_min = as.Date(harv_min_raw),
      term_min = as.Date(term_min_raw),
      next_min = as.Date(next_min_raw),

      crop_end = dplyr::case_when(
        CD_cat == "Annual" & (!is.na(harv_min) | !is.na(term_min)) ~
          pmin(harv_min, term_min, na.rm = TRUE),
        CD_cat == "Annual" & is.na(harv_min) & is.na(term_min) &
          !is.na(next_min) ~ next_min,
        CD_cat == "Annual" & is.na(harv_min) & is.na(term_min) &
          is.na(next_min) ~ rot_end,

        CD_cat == "Perennial" & !is.na(term_min) ~ term_min,
        CD_cat == "Perennial" & is.na(term_min) & !is.na(next_min) ~ next_min,
        CD_cat == "Perennial" & is.na(term_min) & is.na(next_min) ~ rot_end
      )
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(
      MGT_combo, CD_seq_num, CD_mix, CD_cat, CD_group, CD_name,
      crop_start, crop_end, rot_start, rot_end, rot_start_yr, rot_end_yr
    ) %>%
    dplyr::mutate(
      crop_start = as.Date(crop_start),
      crop_end   = as.Date(crop_end)
    )

  # ------------------------------------------------------------
  # 11. Apply interval-aware clipping to harmonized windows
  # ------------------------------------------------------------
  # start_date_override
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)

    crop <- crop %>%
      dplyr::filter(crop_end >= S) %>%
      dplyr::mutate(
        crop_start = if_else(crop_start < S, S, crop_start)
      )

    dist <- dist %>%
      dplyr::filter(SD_date >= S)

    amend <- amend %>%
      dplyr::filter(SA_date >= S)

    animal <- animal %>%
      dplyr::filter(AD_end_date >= S) %>%
      dplyr::mutate(
        AD_start_date = if_else(AD_start_date < S, S, AD_start_date)
      )
  }

  # end_date_override
  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)

    crop <- crop %>%
      dplyr::filter(crop_start <= E) %>%
      dplyr::mutate(
        crop_end = if_else(crop_end > E, E, crop_end)
      )

    dist <- dist %>%
      dplyr::filter(SD_date <= E)

    amend <- amend %>%
      dplyr::filter(SA_date <= E)

    animal <- animal %>%
      dplyr::filter(AD_start_date <= E) %>%
      dplyr::mutate(
        AD_end_date = if_else(AD_end_date > E, E, AD_end_date)
      )
  }

  # end_sample_date
  if (end_sample_date) {

    crop <- crop %>%
      dplyr::left_join(mgt_dates, by = "MGT_combo") %>%
      dplyr::filter(crop_start <= MGT_sample_date) %>%
      dplyr::mutate(
        crop_end = if_else(crop_end > MGT_sample_date,
                           MGT_sample_date, crop_end)
      )

    dist <- dist %>%
      dplyr::left_join(mgt_dates, by = "MGT_combo") %>%
      dplyr::filter(SD_date <= MGT_sample_date)

    amend <- amend %>%
      dplyr::left_join(mgt_dates, by = "MGT_combo") %>%
      dplyr::filter(SA_date <= MGT_sample_date)

    animal <- animal %>%
      dplyr::left_join(mgt_dates, by = "MGT_combo") %>%
      dplyr::filter(AD_start_date <= MGT_sample_date) %>%
      dplyr::mutate(
        AD_end_date = if_else(AD_end_date > MGT_sample_date,
                              MGT_sample_date, AD_end_date)
      )
  }

  # ------------------------------------------------------------
  # 12. Validation
  # ------------------------------------------------------------
  ch <- crop

  missing_end <- ch %>% dplyr::filter(is.na(crop_end))
  if (nrow(missing_end) > 0) {
    stop(
      "Error: Some crops still have no end date even after inference:\n",
      paste0("  - ", missing_end$MGT_combo, " seq ", missing_end$CD_seq_num),
      call. = FALSE
    )
  }

  bad_order <- ch %>% dplyr::filter(crop_end < crop_start)
  if (nrow(bad_order) > 0) {
    stop(
      "Error: crop_end is before crop_start:\n",
      paste0("  - ", bad_order$MGT_combo, " seq ", bad_order$CD_seq_num),
      call. = FALSE
    )
  }

  # ------------------------------------------------------------
  # 13. Yield / N-rate
  # ------------------------------------------------------------
  if (calc_yield) {
    cli::cli_progress_step("Computing crop yields...")
    yield <- .prepare_yield(
      path,
      exclude = exclude,
      start_date_override = start_date_override,
      end_date_override   = end_date_override
    )
  } else {
    yield <- NULL
  }

  if (calc_n_rate) {
    cli::cli_progress_step("Computing N rates...")
    n_rate <- .prepare_n_rate(
      path,
      exclude = exclude,
      start_date_override = start_date_override,
      end_date_override   = end_date_override
    )
  } else {
    n_rate <- NULL
  }

  cli::cli_progress_done()
  cli::cli_progress_cleanup()

  # ------------------------------------------------------------
  # 14. Return
  # ------------------------------------------------------------
  list(
    rot_bounds = rot_bounds,
    mgt        = mgt,
    crop       = crop,
    dist       = dist,
    amend      = amend,
    animal     = animal,
    yield      = yield,
    n_rate     = n_rate
  )
}
