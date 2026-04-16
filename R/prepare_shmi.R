#' Prepare and Validate SHMI Input Data from an Excel Workbook
#'
#' Reads, validates, harmonizes, and expands all input sheets required to
#' compute the Soil Health Management Index (SHMI). This function is the
#' official entry point for SHMI data preparation and produces a standardized
#' list of objects used directly by \code{build_shmi()}.
#'
#' The function performs:
#' \itemize{
#'   \item robust Excel ingestion with sheet‑level validation
#'   \item management‑unit filtering
#'   \item crop‑level biological validation (chronology, annual/perennial rules)
#'   \item harmonization of crop windows across mixtures
#'   \item construction of rotation bounds
#'   \item daily grid expansion (fast vectorized implementation)
#'   \item mechanistic daily disturbance processing (mixing efficiency × depth)
#'   \item assembly of amendment and animal event tables
#' }
#'
#' @param path Path to the SHMI Excel workbook. Must contain the standard SHMI
#'   sheets: \code{Mgt_Unit}, \code{Crop_Diversity}, \code{Soil_Disturbance},
#'   \code{Amendment_Diversity}, and \code{Animal_Diversity}. Sheets may be
#'   empty; empty sheets are safely ignored.
#'
#' @param exclude Optional character vector of \code{MGT_combo} identifiers to
#'   exclude from processing. Default is \code{NULL}.
#'
#' @param verbose Logical; if \code{TRUE} (default), prints progress messages
#'   describing sheet ingestion, validation steps, and grid construction.
#'
#' @param start_date_override Optional \code{Date} or date‑coercible value.
#'   If supplied, all crop, disturbance, amendment, and animal events occurring
#'   before this date are removed, and rotation bounds are clipped accordingly.
#'
#' @param end_date_override Optional \code{Date} or date‑coercible value.
#'   If supplied, all events occurring after this date are removed, and rotation
#'   bounds are clipped accordingly.
#'
#' @details
#' The function enforces biologically realistic crop windows, including:
#' \itemize{
#'   \item annual crops must terminate within the same year
#'   \item perennials may span years but must follow valid chronology
#'   \item mixtures are collapsed to event‑level windows
#' }
#'
#' Rotation bounds are computed from all available event types (crop,
#' disturbance, amendment, animal). Empty sheets contribute no bounds.
#'
#' Daily grids are generated using a fully vectorized expansion, ensuring
#' extremely fast performance even for large datasets.
#'
#' Additionally, this function automatically performs front‑end validation of
#' the Excel input file using \code{validate_excel_input()}. The validator checks
#' for required sheets, required columns, valid date formats, consistent
#' \code{MGT_combo} values, and malformed entries before any ingestion or
#' harmonization occurs.
#'
#' If validation fails, execution stops immediately with clear, actionable error
#' messages. Users must correct the Excel file before re‑running
#' \code{prepare_shmi_inputs()}.
#'
#' @return A named list containing:
#' \describe{
#'   \item{\code{rot_bounds}}{Rotation start/end dates for each \code{MGT_combo}.}
#'   \item{\code{crop_harmonized}}{One row per crop event with harmonized
#'         start/end dates.}
#'   \item{\code{daily}}{Daily crop‑presence grid (one row per day).}
#'   \item{\code{daily_dist}}{Daily disturbance table with mixing efficiency and
#'         depth (cm).}
#'   \item{\code{mgt}}{Management‑unit metadata.}
#'   \item{\code{crop}}{Validated crop event table.}
#'   \item{\code{dist}}{Disturbance event table.}
#'   \item{\code{amend}}{Amendment event table.}
#'   \item{\code{animal}}{Animal event table.}
#' }
#'
#' @section Error Handling:
#' The function stops with informative errors if:
#' \itemize{
#'   \item required sheets are missing
#'   \item required columns are missing
#'   \item crop chronology is biologically impossible
#'   \item date overrides produce empty rotations
#' }
#'
#' @seealso \code{\link{build_shmi}} for computing SHMI scores from the returned
#'   object.
#'
#' @export
prepare_shmi_inputs <- function(path,
                                exclude = NULL,
                                verbose = TRUE,
                                start_date_override = NULL,
                                end_date_override = NULL) {

  # Validate Excel file before ingestion
  val <- validate_excel_input(path)

  if (!val$ok) {
    message("❌ Excel input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run prepare_shmi_inputs().")
  }

  message("✅ Excel input validation passed.\n")
  message("Input summary:")
  print(val$summary)

  if (length(val$warnings) > 0) {
    message("\nWarnings:")
    message(paste0(" - ", val$warnings, collapse = "\n"))
  }

  # ---- Normalize override dates ----
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
  # 1. Exclusion lists
  # ------------------------------------------------------------
  if (verbose) {
    message("Excluding ", length(exclude), " management units:")
    message(paste("  -", exclude, collapse = "\n"))
  }

  # ------------------------------------------------------------
  # 2. Helper to read + filter sheets
  # ------------------------------------------------------------
  safe_select <- function(df, cols) {
    cols <- intersect(cols, names(df))
    dplyr::select(df, all_of(cols))
  }

  safe_read <- function(sheet, required_cols, ...) {

    # If sheet doesn't exist
    if (!sheet %in% readxl::excel_sheets(path)) {
      if (verbose) message("Sheet '", sheet, "' not found; returning empty tibble.")
      return(tibble::tibble(!!!setNames(
        replicate(length(required_cols), logical(), simplify = FALSE),
        required_cols
      )))
    }

    # Try reading
    df <- readxl::read_xlsx(path, sheet = sheet, ...)
    df <- janitor::remove_empty(df, "rows")
    df <- janitor::remove_empty(df, "cols")

    # If empty, return zero-row tibble with correct columns
    if (nrow(df) == 0) {
      if (verbose) message("Sheet '", sheet, "' is empty; returning empty tibble.")
      return(tibble::tibble(!!!setNames(
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

  # ------------------------------------------------------------
  # 3. Load MGT first (needed for joins)
  # ------------------------------------------------------------
  mgt <- read_xlsx(path, sheet = "Mgt_Unit", skip = 3, range = NULL) %>%
    select(user_name, MGT_combo) %>%
    janitor::remove_empty("rows") %>%
    filter(!(MGT_combo %in% exclude))

  if (verbose) {
    included <- unique(mgt$MGT_combo)
    message("\nIncluded ", length(included), " management units for sheet Mgt_Unit:")
    message(paste("  -", included, collapse = "\n"))
  }

  # ------------------------------------------------------------
  # 4. Load all sheets
  # ------------------------------------------------------------
  parse_date_safe <- function(x) {
    suppressWarnings({
      # Try ymd first
      d <- lubridate::ymd(x, quiet = TRUE)

      # If still NA, try mdy
      d[is.na(d)] <- lubridate::mdy(x[is.na(d)], quiet = TRUE)

      # If still NA, try dmy
      d[is.na(d)] <- lubridate::dmy(x[is.na(d)], quiet = TRUE)

      # If still NA, try Excel serial numbers
      suppressWarnings({
        nums <- suppressWarnings(as.numeric(x))
        d[is.na(d) & !is.na(nums)] <- as.Date(nums[is.na(d) & !is.na(nums)], origin = "1899-12-30")
      })

      # Final: return Date or NA
      d
    })
  }

  # ---- Load Crop_Diversity ----
  crop <- safe_read(
    "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_seq_num", "CD_plant_date", "CD_term_date"),
    skip = 3
  )

  # CD_harv_date is OPTIONAL — add it if missing
  if (!"CD_harv_date" %in% names(crop)) {
    crop$CD_harv_date <- NA
  }

  # Convert dates
  crop <- crop %>%
    mutate(
      CD_plant_date = as.Date(CD_plant_date),
      CD_harv_date  = as.Date(CD_harv_date),
      CD_term_date  = as.Date(CD_term_date)
    )

  # ---- Apply year overrides BEFORE validation ----
  if (!is.null(start_date_override)) {
    crop <- crop %>%
      filter(
        CD_plant_date >= start_date_override |
        CD_harv_date  >= start_date_override |
        CD_term_date  >= start_date_override
      )
  }

  if (!is.null(end_date_override)) {
    crop <- crop %>%
      filter(
        CD_plant_date <= end_date_override |
        CD_harv_date  <= end_date_override |
        CD_term_date  <= end_date_override
      )
  }

  # ---- VALIDATION BLOCK ----

  # 1. At least one end date must exist
  no_end <- crop %>%
    filter(is.na(CD_harv_date) & is.na(CD_term_date))

  if (nrow(no_end) > 0) {
    stop(
      "Error: Crop rows with no harvest or termination date:\n",
      paste0("  - ", no_end$MGT_combo, " seq ", no_end$CD_seq_num),
      call. = FALSE
    )
  }

  # 2. Annual vs perennial logic
  annual    <- crop %>% filter(CD_cat == "Annual")
  perennial <- crop %>% filter(CD_cat != "Annual")

  # Annuals MUST have CD_term_date
  bad_annual_missing_term <- annual %>% filter(is.na(CD_term_date))

  if (nrow(bad_annual_missing_term) > 0) {
    stop(
      "Error: Annual crops must have a termination date (CD_term_date):\n",
      paste0("  - ", bad_annual_missing_term$MGT_combo,
             " seq ", bad_annual_missing_term$CD_seq_num),
      call. = FALSE
    )
  }

  # Annuals: if CD_harv_date exists, it must equal CD_term_date
  bad_annual_harv <- annual %>%
    filter(!is.na(CD_harv_date) & CD_harv_date != CD_term_date)

  if (nrow(bad_annual_harv) > 0) {
    stop(
      "Error: Annual crops must have CD_harv_date equal to CD_term_date (or leave CD_harv_date blank):\n",
      paste0("  - ", bad_annual_harv$MGT_combo,
             " seq ", bad_annual_harv$CD_seq_num),
      call. = FALSE
    )
  }

  # 3. Harvest after termination (impossible)
  bad_order <- crop %>%
    filter(!is.na(CD_harv_date), !is.na(CD_term_date), CD_harv_date > CD_term_date)

  if (nrow(bad_order) > 0) {
    stop(
      "Error: CD_harv_date is after CD_term_date for:\n",
      paste0("  - ", bad_order$MGT_combo, " seq ", bad_order$CD_seq_num),
      call. = FALSE
    )
  }

  # 4. Harvest or termination before planting (impossible)
  bad_within_row <- crop %>%
    filter(
      (!is.na(CD_harv_date) & CD_harv_date < CD_plant_date) |
        (!is.na(CD_term_date) & CD_term_date < CD_plant_date)
    )

  if (nrow(bad_within_row) > 0) {
    stop(
      "Error: Crop has harvest or termination before planting:\n",
      paste0("  - ", bad_within_row$MGT_combo, " seq ", bad_within_row$CD_seq_num),
      call. = FALSE
    )
  }

  # ---- Define crop_end consistently ----
  crop <- crop %>%
    mutate(
      crop_end = case_when(
        !is.na(CD_term_date) ~ CD_term_date,   # annuals + final perennial termination
        !is.na(CD_harv_date) ~ CD_harv_date,   # perennial harvest without termination
        TRUE ~ NA_Date_
      )
    )

  # ---- 5. CD_seq_num must be chronological ----
  bad_seq <- crop %>%
    group_by(MGT_combo) %>%
    arrange(CD_seq_num) %>%
    mutate(
      next_start = lead(CD_plant_date),
      next_seq   = lead(CD_seq_num)
    ) %>%
    filter(!is.na(next_start) & CD_plant_date > next_start)

  if (nrow(bad_seq) > 0) {
    stop(
      "Error: CD_seq_num is not chronological for the following rows:\n",
      paste0("  - ", bad_seq$MGT_combo, " seq ", bad_seq$CD_seq_num,
             " (", bad_seq$CD_plant_date, ") > seq ", bad_seq$next_seq,
             " (", bad_seq$next_start, ")", collapse = "\n"),
      call. = FALSE
    )
  }

  # ---- 6. Same-day planting must share same CD_seq_num ----
  bad_same_date <- crop %>%
    group_by(MGT_combo, CD_plant_date) %>%
    filter(n() > 1) %>%
    summarize(n_seq = n_distinct(CD_seq_num), .groups = "drop") %>%
    filter(n_seq > 1)

  if (nrow(bad_same_date) > 0) {
    stop(
      "Error: Multiple crops with the same planting date have different CD_seq_num values:\n",
      paste0("  - ", bad_same_date$MGT_combo, " on ", bad_same_date$CD_plant_date,
             " has ", bad_same_date$n_seq, " different sequence numbers."),
      call. = FALSE
    )
  }

  # ---- Load Soil_Disturbance ----
  dist <- safe_read(
    "Soil_Disturbance",
    required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
    skip = 3
  )

  if (!is.null(start_date_override)) {
    dist <- dist %>%
      filter(SD_date >= start_date_override)
  }

  if (!is.null(end_date_override)) {
    dist <- dist %>% filter(SD_date <= end_date_override)
  }

  # ---- Load Soil_Amendments ----
  amend <- safe_read(
    "Soil_Amendments",
    required_cols = c("MGT_combo", "SA_date"),
    skip = 3
  )

  if (!is.null(start_date_override)) {
    amend <- amend %>%
      filter(SA_date >= start_date_override)
  }

  if (!is.null(end_date_override)) {
    amend <- amend %>% filter(SA_date <= end_date_override)
  }

  # ---- Load Animal_Diversity ----
  animal <- safe_read(
    "Animal_Diversity",
    required_cols = c("MGT_combo", "AD_start_date", "AD_end_date"),
    skip = 3
  )

  if (!is.null(start_date_override)) {
    animal <- animal %>%
      filter(
        AD_start_date >= start_date_override |
        AD_end_date   >= start_date_override
      )
  }

  if (!is.null(end_date_override)) {
    animal <- animal %>%
      filter(
        AD_start_date <= end_date_override |
        AD_end_date   <= end_date_override
      )
  }

  # ------------------------------------------------------------
  # 5. Harmonize crop windows
  # ------------------------------------------------------------
  harmonize_crop_windows <- function(crop) {

    crop %>%
      mutate(
        CD_plant_date = as.Date(CD_plant_date),
        crop_end      = as.Date(crop_end)
      ) %>%
      group_by(MGT_combo) %>%
      # Determine rotation-level start/end years
      mutate(
        start_yr = min(year(CD_plant_date), na.rm = TRUE),
        end_yr   = max(year(crop_end), na.rm = TRUE)
      ) %>%
      ungroup() %>%
      group_by(MGT_combo, CD_seq_num) %>%
      mutate(
        # Identify first/last crop in rotation
        is_first = CD_seq_num == min(CD_seq_num),
        is_last  = CD_seq_num == max(CD_seq_num),

        # Raw windows across mixtures
        start_raw = suppressWarnings(min(CD_plant_date, na.rm = TRUE)),
        end_raw   = suppressWarnings(max(crop_end, na.rm = TRUE)),

        start_raw = if_else(is.infinite(start_raw), NA_Date_, start_raw),
        end_raw   = if_else(is.infinite(end_raw),   NA_Date_, end_raw)
      ) %>%
      summarize(
        CD_group = paste(unique(CD_group), collapse = " + "),
        CD_name  = paste(unique(CD_name),  collapse = " + "),

        # Start date logic:
        # - If first crop and missing start_raw → fallback to Jan 1 of start_yr
        # - Otherwise use start_raw
        crop_start = first(
          if_else(
            is_first & is.na(start_raw),
            as.Date(paste0(start_yr, "-01-01")),
            start_raw
          )
        ),

        # End date logic:
        # - If last crop and missing end_raw → fallback to Dec 31 of end_yr
        # - Otherwise use end_raw
        crop_end = first(
          if_else(
            is_last & is.na(end_raw),
            as.Date(paste0(end_yr, "-12-31")),
            end_raw
          )
        ),

        .groups = "drop"
      )
  }

  crop_harmonized <- harmonize_crop_windows(crop)

  if (!is.null(start_date_override)) {
    crop_harmonized <- crop_harmonized %>%
      mutate(crop_start = pmax(crop_start, start_date_override))
  }

  if (!is.null(end_date_override)) {
    crop_harmonized <- crop_harmonized %>%
      mutate(crop_end = pmin(crop_end, end_date_override))
  }

  # ------------------------------------------------------------
  # 6. Bounds helper
  # ------------------------------------------------------------
  compute_bounds <- function(crop_harmonized, dist, amend, animal) {

    # Helper: drop NULL or empty data frames
    clean_df <- function(df, date_cols) {
      if (is.null(df)) return(NULL)
      if (nrow(df) == 0) return(NULL)

      df <- df %>% filter(!is.na(MGT_combo))

      # Keep only rows with at least one non-NA date
      df <- df %>%
        filter(rowSums(!is.na(across(all_of(date_cols)))) > 0)

      if (nrow(df) == 0) return(NULL)
      df
    }

    crop_h  <- clean_df(crop_harmonized, c("crop_start", "crop_end"))
    dist_h  <- clean_df(dist,           c("SD_date"))
    amend_h <- clean_df(amend,          c("SA_date"))
    animal_h<- clean_df(animal,         c("AD_start_date", "AD_end_date"))

    # Build list of non-null data frames
    dfs <- list(crop_h, dist_h, amend_h, animal_h)
    dfs <- dfs[!vapply(dfs, is.null, logical(1))]

    # If no data at all, error
    if (length(dfs) == 0) {
      stop("No valid crop, disturbance, amendment, or animal data found.", call. = FALSE)
    }

    # Summaries
    summarize_bounds <- function(df, start_col, end_col) {
      df %>%
        group_by(MGT_combo) %>%
        summarize(
          start = min(.data[[start_col]], na.rm = TRUE),
          end   = max(.data[[end_col]],   na.rm = TRUE),
          .groups = "drop"
        )
    }

    df_list <- list()

    if (!is.null(crop_h))  df_list[[length(df_list)+1]] <- summarize_bounds(crop_h,  "crop_start", "crop_end")
    if (!is.null(dist_h))  df_list[[length(df_list)+1]] <- summarize_bounds(dist_h,  "SD_date",   "SD_date")
    if (!is.null(amend_h)) df_list[[length(df_list)+1]] <- summarize_bounds(amend_h, "SA_date",   "SA_date")
    if (!is.null(animal_h))df_list[[length(df_list)+1]] <- summarize_bounds(animal_h,"AD_start_date","AD_end_date")

    # Combine
    df_all <- bind_rows(df_list)

    rot_bounds <- df_all %>%
      group_by(MGT_combo) %>%
      summarize(
        rot_start = min(start, na.rm = TRUE),
        rot_end   = max(end,   na.rm = TRUE),
        .groups = "drop"
      )

    rot_bounds
  }

  rot_bounds <- compute_bounds(crop_harmonized, dist, amend, animal)

  if (!is.null(start_date_override)) {
    rot_bounds$rot_start <- pmax(rot_bounds$rot_start, start_date_override)
  }

  if (!is.null(end_date_override)) {
    rot_bounds$rot_end <- pmin(rot_bounds$rot_end, end_date_override)
  }

  rot_bounds <- rot_bounds %>%
    dplyr::mutate(
      rot_start_yr = lubridate::year(as.Date(rot_start)),
      rot_end_yr   = lubridate::year(as.Date(rot_end))
    )

  # ------------------------------------------------------------
  # 10. Daily disturbance summary
  # ------------------------------------------------------------
  daily_dist <- dist %>%
    mutate(
      date = as.Date(SD_date),
      SD_depth_cm = pmin(SD_depth * 2.54, 30)
    ) %>%
    group_by(MGT_combo, date) %>%
    summarize(
      SD_mixeff = sum(SD_mixeff, na.rm = TRUE),
      SD_depth_cm = max(SD_depth_cm, na.rm = TRUE),
      .groups = "drop"
    )

  # ------------------------------------------------------------
  # 11. Build daily grid
  # ------------------------------------------------------------

  build_daily_grid <- function(crop_harmonized, rot_bounds, daily_dist, verbose = FALSE) {

    if (verbose) message("Building the rotation grid...")

    rot_grid <- rot_bounds %>%
      dplyr::mutate(
        rot_start_date = as.Date(rot_start),
        rot_end_date   = as.Date(rot_end),
        n_days = as.integer(rot_end_date - rot_start_date) + 1
      ) %>%
      tidyr::uncount(n_days) %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::mutate(
        date = rot_start_date + (dplyr::row_number() - 1L)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::select(-rot_start_date, -rot_end_date)

    if (verbose) message("Building the crop grid...")

    crop_grid <- crop_harmonized %>%
      dplyr::mutate(
        n_days = as.integer(crop_end - crop_start) + 1L
      ) %>%
      tidyr::uncount(n_days) %>%
      dplyr::group_by(MGT_combo, CD_seq_num) %>%
      dplyr::mutate(
        date = crop_start + (dplyr::row_number() - 1L)
      ) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(crop_present = 1L)

    if (verbose) message("Combining grids...")

    # Make sure disturbance dates are also Date for joining
    daily_dist_clean <- daily_dist %>%
      dplyr::mutate(date = as.Date(date))

    daily <- rot_grid %>%
      dplyr::left_join(crop_grid, by = c("MGT_combo", "date")) %>%
      dplyr::mutate(
        crop_present = tidyr::replace_na(crop_present, 0L)
      ) %>%
      dplyr::left_join(daily_dist_clean, by = c("MGT_combo", "date")) %>%
      dplyr::mutate(
        SD_mixeff   = tidyr::replace_na(SD_mixeff, 0),
        SD_depth_cm = tidyr::replace_na(SD_depth_cm, 0)
      )

    daily
  }

  daily <- build_daily_grid(crop_harmonized, rot_bounds, daily_dist)

  # ------------------------------------------------------------
  # 12. Return everything in one clean list
  # ------------------------------------------------------------
  list(
    rot_bounds      = rot_bounds,
    crop_harmonized = crop_harmonized,
    daily           = daily,
    daily_dist      = daily_dist,
    mgt             = mgt,
    crop            = crop,
    dist            = dist,
    amend           = amend,
    animal          = animal
  )
}
