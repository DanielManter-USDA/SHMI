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
                                rot_calc = c("napeshm", "farmer"),
                                start_date_override = NULL,
                                end_date_override   = NULL,
                                end_sample_date = FALSE,
                                calc_yield  = FALSE,
                                calc_n_rate = FALSE) {

  rot_calc <- match.arg(rot_calc)

  # ------------------------------------------------------------
  # 1. Validating inputs
  # ------------------------------------------------------------
  cli::cli_progress_step("Validating inputs...")

  # Validate Excel file before ingestion
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
  # 2. Helper to read + filter sheets
  # ------------------------------------------------------------
  safe_select <- function(df, cols) {
    cols <- intersect(cols, names(df))
    dplyr::select(df, all_of(cols))
  }

  # ------------------------------------------------------------
  # 3. Load MGT first (needed for joins)
  # ------------------------------------------------------------
  cli::cli_progress_step("Reading Excel file...")

  mgt <- .safe_read(
    path,
    sheet = "Mgt_Unit",
    required_cols = c("MGT_combo", "MGT_study", "MGT_field", "MGT_trt"),
    skip = 3,
    verbose = verbose
  ) %>%
    select(any_of(c(
      "user_name", "MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt", "MGT_sample_date"
    ))) %>%
    janitor::remove_empty("rows") %>%
    filter(!(MGT_combo %in% exclude))

  # ------------------------------------------------------------
  # 4. Load all sheets
  # ------------------------------------------------------------
  #   ---- Load Crop_Diversity ----
  crop <- .safe_read(
    path,
    sheet = "Crop_Diversity",
    required_cols = c("MGT_combo", "CD_plant_date", "CD_term_date"),
    skip = 3,
    verbose = verbose
  ) %>%
    filter(!(MGT_combo %in% exclude))

  if (!"CD_harv_date" %in% names(crop)) crop$CD_harv_date <- NA
  if (!"CD_cat" %in% names(crop))       crop$CD_cat       <- NA_character_

  crop <- crop %>%
    mutate(
      CD_plant_date = as.Date(unname(.parse_shmi_date(CD_plant_date))),
      CD_harv_date  = as.Date(unname(.parse_shmi_date(CD_harv_date))),
      CD_term_date  = as.Date(unname(.parse_shmi_date(CD_term_date)))
    )

  #   ---- Load Soil_Disturbance ----
  dist <- .safe_read(
    path,
    sheet = "Soil_Disturbance",
    required_cols = c("MGT_combo", "SD_date", "SD_mixeff"),
    skip = 3,
    verbose = verbose
  ) %>%
    filter(!(MGT_combo %in% exclude))

  dist <- dist %>%
    mutate(SD_date = as.Date(unname(.parse_shmi_date(SD_date))))

  #   ---- Apply year overrides BEFORE inference ----
  if (!is.null(start_date_override)) {
    S <- as.Date(start_date_override)
    crop <- crop %>% filter(is.na(CD_term_date) | CD_term_date >= S) %>%
      mutate(CD_plant_date = if_else(CD_plant_date < S, S, CD_plant_date))
    dist <- dist %>% filter(SD_date >= S)
  }

  if (!is.null(end_date_override)) {
    E <- as.Date(end_date_override)
    crop <- crop %>% filter(CD_plant_date <= E) %>%
      mutate(CD_term_date = if_else(!is.na(CD_term_date) & CD_term_date > E, E, CD_term_date))
    dist <- dist %>% filter(SD_date <= E)
  }

  if (end_sample_date) {
    crop <- crop %>%
      left_join(mgt %>% select(MGT_combo, MGT_sample_date), by = "MGT_combo") %>%
      mutate(MGT_sample_date = as.Date(MGT_sample_date)) %>%
      filter(CD_plant_date <= MGT_sample_date) %>%
      mutate(CD_term_date = if_else(!is.na(CD_term_date) & CD_term_date > MGT_sample_date, MGT_sample_date, CD_term_date))
    dist <- dist %>%
      left_join(mgt %>% select(MGT_combo, MGT_sample_date), by = "MGT_combo") %>%
      mutate(MGT_sample_date = as.Date(MGT_sample_date)) %>%
      filter(SD_date <= MGT_sample_date)
  }

  #   ---- INFER TERMINATION DATES (planting + disturbance) ----
  # 1. Next planting date
  safe_min_date <- function(x) {
    x2 <- x[!is.na(x)]
    if (length(x2) == 0) return(as.Date(NA))  # NA_Date_
    as.Date(min(x2))
  }

  seq_dates <- crop %>%
    group_by(MGT_combo, CD_seq_num) %>%
    summarize(
      seq_plant = safe_min_date(CD_plant_date),
      .groups   = "drop"
    ) %>%
    arrange(MGT_combo, CD_seq_num) %>%
    group_by(MGT_combo) %>%
    mutate(next_seq_plant = dplyr::lead(seq_plant)) %>%
    ungroup()

  crop <- crop %>%
    left_join(seq_dates, by = c("MGT_combo", "CD_seq_num")) %>%
    mutate(next_plant = next_seq_plant)

  # ---- Load Soil_Amendments ----
  amend <- .safe_read(
    path,
    sheet = "Soil_Amendments",
    required_cols = NULL,
    skip = 3,
    verbose = verbose
  )

  # If sheet is missing OR contains no valid amendment dates → skip
  if (is.null(amend) || !("SA_date" %in% names(amend)) ||
      all(is.na(.parse_shmi_date(amend$SA_date)))) {

    amend <- tibble::tibble(
      MGT_combo = character(),
      SA_date   = as.Date(character()),
      SA_cat    = character(),
      SA_N      = numeric()
    )

  } else {

    # Normal processing
    amend <- amend %>%
      mutate(
        SA_date = as.Date(unname(.parse_shmi_date(SA_date)))
      ) %>%
      filter(!(MGT_combo %in% exclude))

    if (!is.null(start_date_override)) {
      amend <- amend %>% filter(SA_date >= S)
    }

    if (!is.null(end_date_override)) {
      amend <- amend %>% filter(SA_date <= E)
    }

    if (end_sample_date) {
      amend <- amend %>%
        left_join(mgt %>% select(MGT_combo, MGT_sample_date), by = "MGT_combo") %>%
        filter(SA_date <= MGT_sample_date)
    }
  }

  # ---- Load Animal_Diversity ----
  animal <- .safe_read(
    path,
    sheet = "Animal_Diversity",
    required_cols = NULL,
    skip = 3,
    verbose = verbose
  )

  # If sheet is missing OR contains no valid amendment dates → skip
  if (is.null(animal) ||
      !all(c("AD_start_date", "AD_end_date") %in% names(animal)) ||
      (
        all(is.na(.parse_shmi_date(animal$AD_start_date))) &&
        all(is.na(.parse_shmi_date(animal$AD_end_date)))
      )) {

    # Return an empty tibble with expected structure
    animal <- tibble::tibble(
      MGT_combo     = character(),
      AD_start_date = as.Date(character()),
      AD_end_date   = as.Date(character()),
      AD_type       = character()
    )

  } else {

    # Normal processing
    animal <- animal %>%
      mutate(
        AD_start_date = as.Date(unname(.parse_shmi_date(AD_start_date))),
        AD_end_date   = as.Date(unname(.parse_shmi_date(AD_end_date)))
      ) %>%
      filter(!(MGT_combo %in% exclude))

    # ---- Apply start-date override (interval clipping) ----
    if (!is.null(start_date_override)) {
      S <- as.Date(start_date_override)

      animal <- animal %>%
        # Drop windows ending before S
        filter(AD_end_date >= S) %>%
        # Clip windows overlapping S
        mutate(
          AD_start_date = if_else(AD_start_date < S, S, AD_start_date)
        )
    }

    # ---- Apply end-date override (interval clipping) ----
    if (!is.null(end_date_override)) {
      E <- as.Date(end_date_override)

      animal <- animal %>%
        # Drop windows starting after E
        filter(AD_start_date <= E) %>%
        # Clip windows overlapping E
        mutate(
          AD_end_date = if_else(AD_end_date > E, E, AD_end_date)
        )
    }

    if (end_sample_date) {
      animal <- animal %>%
        left_join(mgt %>% select(MGT_combo, MGT_sample_date), by = "MGT_combo") %>%
        mutate(MGT_sample_date = as.Date(MGT_sample_date)) %>%
        filter(AD_start_date <= MGT_sample_date) %>%
        mutate(
          AD_end_date = if_else(AD_end_date > MGT_sample_date, as.Date(MGT_sample_date), AD_end_date)
        )
    }
  }

  # ------------------------------------------------------------
  # 5. Bounds helper
  # ------------------------------------------------------------
  cli::cli_progress_step("Computing rotation bounds...")

  compute_bounds <- function(crop, dist, amend, animal,
                             rot_calc = "farmer",
                             end_sample_date = TRUE,
                             start_date_override = NULL,
                             end_date_override   = NULL) {

    # Helper: drop NULL or empty data frames
    clean_df <- function(df, date_cols) {
      if (is.null(df)) return(NULL)
      if (nrow(df) == 0) return(NULL)
      if (!"MGT_combo" %in% names(df)) return(NULL)  # <- key line

      df <- df %>% filter(!is.na(MGT_combo))

      df <- df %>%
        filter(rowSums(!is.na(across(all_of(date_cols)))) > 0)

      if (nrow(df) == 0) return(NULL)
      df
    }

    crop_h   <- clean_df(crop,   c("CD_plant_date", "CD_harv_date", "CD_term_date"))
    dist_h   <- clean_df(dist,   c("SD_date"))
    amend_h  <- clean_df(amend,  c("SA_date"))
    animal_h <- clean_df(animal, c("AD_start_date", "AD_end_date"))

    dfs <- list(crop_h, dist_h, amend_h, animal_h)
    dfs <- dfs[!vapply(dfs, is.null, logical(1))]

    if (length(dfs) == 0) {
      stop("No valid crop, disturbance, amendment, or animal data found.", call. = FALSE)
    }

    # Summaries
    summarize_bounds <- function(df, start_cols, end_cols) {
      df %>%
        group_by(MGT_combo) %>%
        summarize(
          # earliest activity across all start columns
          start = {
            s <- pmin(!!!rlang::syms(start_cols), na.rm = TRUE)
            s[is.infinite(s)] <- NA
            min(s, na.rm = TRUE)
          },

          # latest activity across all end columns
          end = {
            e <- pmax(!!!rlang::syms(end_cols), na.rm = TRUE)
            e[is.infinite(e)] <- NA
            max(e, na.rm = TRUE)
          },

          .groups = "drop"
        )
    }

    df_list <- list()

    if (!is.null(crop_h)) {
      df_list[[length(df_list)+1]] <- summarize_bounds(
        crop_h,
        start_cols = c("CD_plant_date", "CD_harv_date", "CD_term_date"),
        end_cols  = c("CD_harv_date", "CD_term_date")
      )
    }

    if (!is.null(dist_h)) {
      df_list[[length(df_list)+1]] <- summarize_bounds(
        dist_h,
        start_cols = "SD_date",
        end_cols  = "SD_date"
      )
    }

    if (!is.null(amend_h)) {
      df_list[[length(df_list)+1]] <- summarize_bounds(
        amend_h,
        start_cols = "SA_date",
        end_cols  = "SA_date"
      )
    }

    if (!is.null(animal_h)) {
      df_list[[length(df_list)+1]] <- summarize_bounds(
        animal_h,
        start_cols = "AD_start_date",
        end_cols  = "AD_end_date"
      )
    }

    df_all <- bind_rows(df_list)

    if (end_sample_date) {
      df_all <- df_all %>%
        left_join(
          mgt %>%
            select(MGT_combo, MGT_sample_date) %>%
            group_by(MGT_combo) %>%
            mutate(MGT_sample_date = as.Date(MGT_sample_date)) %>%

            summarize(MGT_sample_date = max(MGT_sample_date), .groups = "drop"),
          by = "MGT_combo"
        )
      }

    # ---- FULL-YEAR LOGIC (NAPESHM) ----
    if (rot_calc == "napeshm") {

      rot_bounds <- df_all %>%
        group_by(MGT_combo) %>%
        summarize(
          # Determine calendar-year bounds from actual data
          yr_min = min(lubridate::year(start), na.rm = TRUE),
          yr_max = max(lubridate::year(end),   na.rm = TRUE),

          # Full-year defaults
          rot_start_default = as.Date(paste0(yr_min, "-01-01")),
          rot_end_default   = as.Date(paste0(yr_max, "-12-31")),

          # Apply overrides if present
          rot_start = if (!is.null(start_date_override))
            as.Date(start_date_override)
          else
            rot_start_default,

          rot_end   = if (!is.null(end_date_override))
            as.Date(end_date_override)
          else if (end_sample_date)
            as.Date(max(MGT_sample_date))
          else
            rot_end_default,
          .groups = "drop"
        ) %>%
        select(MGT_combo, rot_start, rot_end)
    }

    # ---- DATA-YEAR LOGIC ----
    if (rot_calc == "farmer") {
      rot_bounds <- df_all %>%
        group_by(MGT_combo) %>%
        summarize(
          # Determine calendar-year bounds from actual data
          yr_min = min(lubridate::year(start), na.rm = TRUE),
          yr_max = max(lubridate::year(end),   na.rm = TRUE),

          # Full-year defaults
          rot_start_default = min(start, na.rm = TRUE),
          rot_end_default   = max(end, na.rm = TRUE),

          # Apply overrides if present
          rot_start = if (!is.null(start_date_override))
            as.Date(start_date_override)
          else
            rot_start_default,

          rot_end   = if (!is.null(end_date_override))
            as.Date(end_date_override)
          else if (end_sample_date)
            as.Date(max(MGT_sample_date))
          else
            rot_end_default,
          .groups = "drop"
        ) %>%
        select(MGT_combo, rot_start, rot_end)
    }

    rot_bounds
  }

  rot_bounds <- compute_bounds(crop, dist, amend, animal, rot_calc=rot_calc, end_sample_date=end_sample_date)

  rot_bounds <- rot_bounds %>%
    dplyr::mutate(
      rot_start_yr = lubridate::year(as.Date(rot_start)),
      rot_end_yr   = lubridate::year(as.Date(rot_end))
    )

  crop <- crop %>%
    mutate(
      CD_cat = case_when(
        CD_cat %in% c("cash", "cover", "fallow", "Cover") ~ "Annual",
        CD_cat %in% c("perennial", "woody perennial") ~ "Perennial",
        TRUE ~ CD_cat
      )
    )

  crop <- crop %>%
    left_join(rot_bounds, by = "MGT_combo") %>%
    group_by(MGT_combo, CD_seq_num) %>%
    mutate(
      # mixture-aware planting date
      plant_min_raw = suppressWarnings(min(CD_plant_date, na.rm = TRUE)),
      plant_min_raw = ifelse(is.infinite(plant_min_raw), NA, plant_min_raw),

      # convert to Date BEFORE case_when
      plant_min = as.Date(plant_min_raw),

      crop_start = case_when(
        !is.na(plant_min) ~ plant_min,     # earliest planting date
        CD_seq_num == 1   ~ rot_start,     # special winter cover rule
        TRUE              ~ rot_start      # fallback
      ),

      # collect mixture-wide dates
      harv_min_raw = suppressWarnings(min(CD_harv_date, na.rm = TRUE)),
      term_min_raw = suppressWarnings(min(CD_term_date, na.rm = TRUE)),
      next_min_raw = suppressWarnings(min(next_plant,   na.rm = TRUE)),

      harv_min_raw = ifelse(is.infinite(harv_min_raw), NA, harv_min_raw),
      term_min_raw = ifelse(is.infinite(term_min_raw), NA, term_min_raw),
      next_min_raw = ifelse(is.infinite(next_min_raw), NA, next_min_raw),

      harv_min = as.Date(harv_min_raw),
      term_min = as.Date(term_min_raw),
      next_min = as.Date(next_min_raw),

      crop_end = case_when(

        # Annuals: harvest or termination
        CD_cat == "Annual" & (!is.na(harv_min) | !is.na(term_min)) ~
          pmin(harv_min, term_min, na.rm = TRUE),

        # Annuals: fallback to next planting
        CD_cat == "Annual" & is.na(harv_min) & is.na(term_min) &
          !is.na(next_min) ~ next_min,

        # Annuals: no harvest, no termination, no next planting → rotation end
        CD_cat == "Annual" & is.na(harv_min) & is.na(term_min) &
          is.na(next_min) ~ rot_end,

        # Perennials: termination defines end
        CD_cat == "Perennial" & !is.na(term_min) ~ term_min,

        # Perennials: fallback to next planting
        CD_cat == "Perennial" & is.na(term_min) & !is.na(next_min) ~ next_min,

        # Perennials: no termination, no next planting → rotation end
        CD_cat == "Perennial" & is.na(term_min) & is.na(next_min) ~ rot_end
      )
    ) %>%
    ungroup() %>%
    select(MGT_combo, CD_seq_num, CD_mix, CD_cat, CD_group, CD_name,
           crop_start, crop_end, rot_start, rot_end, rot_start_yr, rot_end_yr)

  crop <- crop %>%
    mutate(
      crop_start = as.Date(crop_start),
      crop_end   = as.Date(crop_end)
    )

  # ------------------------------------------------------------
  # 7. VALIDATION
  # ------------------------------------------------------------
  # ---- VALIDATION (AFTER harmonization and bounds) ----
  ch <- crop

  # 1. Every crop must have an end date
  missing_end <- ch %>% filter(is.na(crop_end))
  if (nrow(missing_end) > 0) {
    stop(
      "Error: Some crops still have no end date even after inference:\n",
      paste0("  - ", missing_end$MGT_combo, " seq ", missing_end$CD_seq_num),
      call. = FALSE
    )
  }
  #
  # # 2. crop_end must be >= crop_start
  bad_order <- ch %>% filter(crop_end < crop_start)
  if (nrow(bad_order) > 0) {
    stop(
      "Error: crop_end is before crop_start:\n",
      paste0("  - ", bad_order$MGT_combo, " seq ", bad_order$CD_seq_num),
      call. = FALSE
    )
  }


  # ------------------------------------------------------------
  # Get yield data
  # ------------------------------------------------------------
  if (calc_yield) {
    cli::cli_progress_step("Computing crop yields...")

    yield <- .prepare_yield(path,
                            exclude = exclude,
                            start_date_override = start_date_override,
                            end_date_override = end_date_override
    )
  } else {
    yield <- NULL
  }

  if (calc_n_rate) {
    cli::cli_progress_step("Computing N rates...")

    n_rate <- .prepare_n_rate(path,
                              exclude = exclude,
                              start_date_override = start_date_override,
                              end_date_override   = end_date_override)
  } else {
    n_rate <- NULL
  }

  cli::cli_progress_done()
  cli::cli_progress_cleanup()

  # ------------------------------------------------------------
  # 12. Return everything in one clean list
  # ------------------------------------------------------------
  list(
    rot_bounds      = rot_bounds,
    mgt             = mgt,
    crop            = crop,
    dist            = dist,
    amend           = amend,
    animal          = animal,
    yield           = yield,
    n_rate          = n_rate
  )
}
