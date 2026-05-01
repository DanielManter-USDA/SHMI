#' Build SHMI Scores from Prepared Inputs
#'
#' Computes the Soil Health Management Index (SHMI) for each management unit
#' (`MGT_combo`) using the harmonized inputs produced by
#' \code{prepare_shmi_inputs()}. SHMI is a weighted composite of four sub-indices:
#' cover, diversity, inverse disturbance, and organic inputs (amendments +
#' animals). By default, the function uses the official national SHMI settings
#' (locked mode). In expert mode, users may override settings, but resulting
#' scores are no longer comparable to the national SHMI scale.
#'
#' Optionally, if yield or nitrogen-rate data were computed in
#' \code{prepare_shmi_inputs()} (via \code{calc_yield = TRUE} or
#' \code{calc_n_rate = TRUE}), this function also produces rotation-level
#' summaries of yield (kg/ha) and nitrogen application rate (kg N/ha). These
#' summaries are merged into the final SHMI output and returned as separate
#' tables for downstream modeling (e.g., N-response curves, ANOVA at N100,
#' yield stability analysis).
#'
#' @param shmi_inputs A list returned by \code{prepare_shmi_inputs()}, containing
#'   at minimum:
#'   \itemize{
#'     \item \code{rot_bounds} — rotation start/end dates
#'     \item \code{crop_harmonized} — harmonized crop windows
#'     \item \code{daily} — daily crop presence table
#'     \item \code{daily_dist} — daily disturbance table
#'     \item \code{amend} — amendment events
#'     \item \code{animal} — animal events
#'   }
#'   Additional optional elements:
#'   \itemize{
#'     \item \code{yield} — crop-event-level yield data (kg/ha), if
#'       \code{calc_yield = TRUE} in \code{prepare_shmi_inputs()}
#'     \item \code{n_rate} — year-level nitrogen application data (kg N/ha), if
#'       \code{calc_n_rate = TRUE} in \code{prepare_shmi_inputs()}
#'   }
#'
#' @param settings Optional named list of SHMI settings (seasonal cover weights,
#'   Hill number, max diversity, pillar weights, etc.). Ignored unless
#'   \code{expert_mode = TRUE}. Missing elements are filled with official
#'   defaults.
#'
#' @param expert_mode Logical; if \code{FALSE} (default), SHMI is computed using
#'   official national settings and any custom \code{settings} are ignored. If
#'   \code{TRUE}, custom settings are allowed but the resulting SHMI values are
#'   not comparable to the national SHMI scale.
#'
#' @details
#' The SHMI computation proceeds in five stages:
#'
#' \enumerate{
#'   \item \strong{Settings}:
#'     In locked mode, the official national SHMI settings are always used.
#'     In expert mode, user-supplied settings override defaults.
#'
#'   \item \strong{Input validation}:
#'     Ensures that all required elements from \code{prepare_shmi_inputs()} are
#'     present and structurally valid.
#'
#'   \item \strong{Pillar computation}:
#'     \itemize{
#'       \item Cover — via \code{compute_cover()}
#'       \item Diversity — via \code{compute_diversity()}
#'       \item Inverse disturbance — via \code{compute_disturbance()}
#'       \item Organic inputs — via \code{compute_orginput()}
#'     }
#'
#'   \item \strong{Weighted combination}:
#'     Sub-indices are normalized so their weights sum to 1, then combined into a
#'     single SHMI score:
#'     \deqn{
#'       SHMI = w_{cover}    \cdot Cover +
#'              w_{div}      \cdot Diversity +
#'              w_{dist}     \cdot InvDist +
#'              w_{orginput} \cdot OrgInputs
#'     }
#'
#'   \item \strong{Optional rotation-level summaries}:
#'     If yield or nitrogen-rate data are present in \code{shmi_inputs}, the
#'     function computes rotation-level summaries:
#'     \itemize{
#'       \item \code{yield_mean}, \code{yield_var}, \code{yield_min},
#'             \code{yield_max}, \code{yield_n}
#'       \item \code{n_rate_mean}, \code{n_rate_var}, \code{n_rate_min},
#'             \code{n_rate_max}, \code{n_years}
#'     }
#'     These summaries are merged into the final SHMI table and also returned
#'     separately for downstream analysis.
#'
#'   \item \strong{Output assembly}:
#'     Returns a tidy data frame of SHMI scores along with metadata describing
#'     the settings used and computation timestamp.
#' }
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{indicator_df} — data frame with columns:
#'       \code{MGT_combo}, \code{SHMI}, \code{Cover}, \code{Diversity},
#'       \code{InvDist}, \code{OrgInputs}, and (if available) yield and N-rate
#'       summaries.
#'     \item \code{yield_summary} — rotation-level yield summaries (or \code{NULL})
#'     \item \code{n_rate_summary} — rotation-level N-rate summaries (or \code{NULL})
#'     \item \code{settings_used} — the settings actually applied
#'     \item \code{expert_mode} — logical flag
#'     \item \code{shmi_version} — version string for reproducibility
#'     \item \code{timestamp} — computation time
#'   }
#'
#' @export
build_shmi <- function(shmi_inputs,
                       settings = NULL,
                       expert_mode = FALSE) {

  steps <- c(
    "Validating inputs",
    "Computing cover",
    "Computing diversity",
    "Computing disturbance",
    "Computing organic inputs",
    "Assembling indicators"
  )

  cli::cli_progress_bar("Building SHMI...")
  cli::cli_progress_step("Validating inputs...")

  val <- validate_shmi_input(shmi_inputs)
  # If validation fails: stop immediately
  if (!val$ok) {
    message("❌ SHMI input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run build_shmi().")
  }

  # --------------------------------------------------------------------------
  # 1. Official national SHMI settings (locked mode)
  # --------------------------------------------------------------------------
  official <- list(
    # cover
    w_winter = 0.130,
    w_spring = 0.129,
    w_summer = 0.513,
    w_fall   = 0.227,

    # diversity
    hill      = 2,
    max_div   = 8,

    # animals / amendments
    w_amend   = 1,
    w_animals = 1,

    # SHMI pillar weights
    w_cover    = 0.492,
    w_div      = 0.052,
    w_dist     = 0.131,
    w_orginput = 0.324
  )

  # --------------------------------------------------------------------------
  # 2. Determine which settings to use
  # --------------------------------------------------------------------------
  if (!expert_mode) {
    if (!is.null(settings)) {
      message(
        "Note: Custom settings ignored because expert_mode = FALSE. ",
        "Using official national SHMI settings."
      )
    }
    settings <- official
  } else {
    message(
      "Expert mode enabled: SHMI scores will NOT be comparable ",
      "to the national SHMI scale."
    )
    settings <- utils::modifyList(official, settings)
  }

  # --------------------------------------------------------------------------
  # 3. Check and extract inputs
  # --------------------------------------------------------------------------
  required <- c("rot_bounds", "crop_harmonized", "daily", "daily_dist",
                "amend", "animal")

  missing <- setdiff(required, names(shmi_inputs))
  if (length(missing) > 0) {
    stop(
      "Missing required inputs in shmi_inputs: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  rot_bounds      <- shmi_inputs$rot_bounds
  crop_harmonized <- shmi_inputs$crop_harmonized
  daily           <- shmi_inputs$daily
  daily_dist      <- shmi_inputs$daily_dist
  amend           <- shmi_inputs$amend
  animal          <- shmi_inputs$animal
  yield           <- shmi_inputs$yield
  n_rate          <- shmi_inputs$n_rate

  # --------------------------------------------------------------------------
  # 4. Compute sub-indices
  # --------------------------------------------------------------------------

  # Cover
  cli::cli_progress_step("Computing cover...")
  cover <- compute_cover(
    daily       = daily,
    rot_bounds  = rot_bounds,
    w_winter    = settings$w_winter,
    w_spring    = settings$w_spring,
    w_summer    = settings$w_summer,
    w_fall      = settings$w_fall
  )

  # Diversity
  cli::cli_progress_step("Computing diversity...")
  diversity <- compute_diversity(
    crop_harmonized = crop_harmonized,
    daily           = daily,
    hill            = settings$hill,
    max_div         = settings$max_div
  )

  # Disturbance (inverse disturbance pillar)
  cli::cli_progress_step("Computing disturbance...")
  invdist <- compute_disturbance(
    daily_dist    = daily_dist,
    rot_bounds    = rot_bounds
  )

  # Organic inputs (amendments + animals)
  cli::cli_progress_step("Computing organic inputs...")
  orginput <- compute_orginput(
    rot_bounds  = rot_bounds,
    amend       = amend,
    animal      = animal,
    w_amend     = settings$w_amend,
    w_animal    = settings$w_animals
  )

  # Yield summary
  yield_summary <- NULL
  if (!is.null(yield)) {
    yield_summary <- yield %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(
        yield_mean = mean(yield_kg_ha, na.rm = TRUE),
        yield_var  = stats::var(yield_kg_ha, na.rm = TRUE),
        yield_min  = min(yield_kg_ha, na.rm = TRUE),
        yield_max  = max(yield_kg_ha, na.rm = TRUE),
        yield_n    = sum(!is.na(yield_kg_ha)),
        .groups = "drop"
      )
  }

  # N-rate summary
  n_rate_summary <- NULL
  if (!is.null(n_rate)) {
    n_rate_summary <- n_rate %>%
      dplyr::group_by(MGT_combo) %>%
      dplyr::summarize(
        n_rate_mean = mean(N_kg_ha, na.rm = TRUE),
        n_rate_var  = stats::var(N_kg_ha, na.rm = TRUE),
        n_rate_min  = min(N_kg_ha, na.rm = TRUE),
        n_rate_max  = max(N_kg_ha, na.rm = TRUE),
        n_years     = sum(!is.na(N_kg_ha)),
        .groups = "drop"
      )
  }

  # --------------------------------------------------------------------------
  # 5. Combine sub-indices
  # --------------------------------------------------------------------------
  cli::cli_progress_step("Combining indices...")
  indicator_df <- purrr::reduce(
    list(cover, diversity, invdist, orginput),
    dplyr::full_join,
    by = "MGT_combo"
  )

  w_sum   <- settings$w_cover + settings$w_div + settings$w_dist + settings$w_orginput

  w_cover    <- settings$w_cover    / w_sum
  w_div      <- settings$w_div      / w_sum
  w_dist     <- settings$w_dist     / w_sum
  w_orginput <- settings$w_orginput / w_sum

  indicator_df <- indicator_df %>%
    dplyr::mutate(
      SHMI = (
          w_cover    * .data$Cover +
          w_div      * .data$Diversity +
          w_dist     * .data$InvDist +
          w_orginput * .data$OrgInputs
      )
    ) %>%
    dplyr::select(.data$MGT_combo, .data$SHMI,
                  .data$Cover, .data$Diversity,
                  .data$InvDist, .data$OrgInputs) %>%
    dplyr::arrange(.data$MGT_combo)

  if (!is.null(yield_summary)) {
    indicator_df <- indicator_df %>%
      dplyr::left_join(yield_summary, by = "MGT_combo")
  }

  if (!is.null(n_rate_summary)) {
    indicator_df <- indicator_df %>%
      dplyr::left_join(n_rate_summary, by = "MGT_combo")
  }

  cli::cli_progress_done()

  if (!expert_mode) {
    message("\n\nSHMI computed using official national settings.")
  }

  # --------------------------------------------------------------------------
  # 6. Return both indicators and settings used
  # --------------------------------------------------------------------------
  list(
    indicator_df = indicator_df,
    yield_summary = yield_summary,
    n_rate_summary = n_rate_summary,
    settings_used = settings,
    expert_mode   = expert_mode,
    shmi_version  = "1.0.2",
    timestamp     = Sys.time()
  )
}
