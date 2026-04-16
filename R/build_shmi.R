#' Build SHMI Scores from Prepared Inputs
#'
#' Computes the Soil Health Management Index (SHMI) for each management unit
#' (`MGT_combo`) using the harmonized inputs produced by
#' \code{prepare_shmi_inputs()}. SHMI is a weighted composite of four pillars:
#' cover, diversity, inverse disturbance, and organic inputs (amendments +
#' animals). By default, the function uses the official national SHMI settings
#' (locked mode). In expert mode, users may override settings, but resulting
#' scores are no longer comparable to the national SHMI scale.
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
#'     present.
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
#'     Pillars are normalized so their weights sum to 1, then combined into a
#'     single SHMI score:
#'     \deqn{
#'       SHMI = w_{cover} \cdot Cover +
#'              w_{div}   \cdot Diversity +
#'              w_{dist}  \cdot InvDist +
#'              w_{ani}   \cdot Animals
#'     }
#'
#'   \item \strong{Output assembly}:
#'     Returns a tidy data frame of SHMI scores along with metadata describing
#'     the settings used and computation timestamp.
#' }
#'
#' Additionally, before computing SHMI pillars, this function automatically
#' validates the internal SHMI data list using \code{validate_shmi_input()}.
#' The validator checks for structural completeness (e.g., required tables,
#' required columns, valid date types, no duplicated daily rows, no missing
#' \code{MGT_combo} values) and ensures that the harmonized data produced by
#' \code{prepare_shmi_inputs()} is consistent and ready for SHMI computation.
#'
#' If validation fails, execution stops immediately with explicit error messages.
#' Users must correct the input data or Excel file before re-running
#' \code{build_shmi()}.
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{indicator_df} — data frame with columns:
#'       \code{MGT_combo}, \code{SHMI}, \code{Cover}, \code{Diversity},
#'       \code{InvDist}, \code{Animals}
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

  val <- validate_shmi_input(dat)
  # If validation fails: stop immediately
  if (!val$ok) {
    message("❌ SHMI input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run build_shmi().")
  }

  # If validation succeeds: print summary and continue
  message("✅ SHMI input validation passed.\n")
  message("Input summary:")
  print(val$summary)

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
    w_ani      = 0.324
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

  # --------------------------------------------------------------------------
  # 4. Compute pillars
  # --------------------------------------------------------------------------

  # Cover
  cover <- compute_cover(
    daily       = daily,
    rot_bounds  = rot_bounds,
    w_winter    = settings$w_winter,
    w_spring    = settings$w_spring,
    w_summer    = settings$w_summer,
    w_fall      = settings$w_fall
  )

  # Diversity
  diversity <- compute_diversity(
    crop_harmonized = crop_harmonized,
    daily           = daily,
    hill            = settings$hill,
    max_div         = settings$max_div
  )

  # Disturbance (inverse disturbance pillar)
  invdist <- compute_disturbance(
    daily_dist    = daily_dist,
    rot_bounds    = rot_bounds
  )

  # Organic inputs (amendments + animals)
  orginput <- compute_orginput(
    rot_bounds  = rot_bounds,
    amend       = amend,
    animal      = animal,
    w_amend     = settings$w_amend,
    w_animal    = settings$w_animals
  )

  # --------------------------------------------------------------------------
  # 5. Combine pillars
  # --------------------------------------------------------------------------
  indicator_df <- purrr::reduce(
    list(cover, diversity, invdist, orginput),
    dplyr::full_join,
    by = "MGT_combo"
  )

  w_sum   <- settings$w_cover + settings$w_div + settings$w_dist + settings$w_ani

  w_cover <- settings$w_cover / w_sum
  w_div   <- settings$w_div   / w_sum
  w_dist  <- settings$w_dist  / w_sum
  w_ani   <- settings$w_ani   / w_sum

  indicator_df <- indicator_df %>%
    dplyr::mutate(
      SHMI = (
        w_cover * .data$Cover +
          w_div   * .data$Diversity +
          w_dist  * .data$InvDist +
          w_ani   * .data$Animals
      )
    ) %>%
    dplyr::select(.data$MGT_combo, .data$SHMI,
                  .data$Cover, .data$Diversity,
                  .data$InvDist, .data$Animals) %>%
    dplyr::arrange(.data$MGT_combo)

  if (!expert_mode) {
    message("SHMI computed using official national settings.")
  }

  # --------------------------------------------------------------------------
  # 6. Return both indicators and settings used
  # --------------------------------------------------------------------------
  list(
    indicator_df = indicator_df,
    settings_used = settings,
    expert_mode   = expert_mode,
    shmi_version  = "1.0.2",
    timestamp     = Sys.time()
  )
}
