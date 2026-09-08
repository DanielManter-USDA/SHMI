#' Build SHMI Scores from Prepared Inputs
#'
#' Computes the Soil Health Management Index (SHMI) for each management unit
#' (`MGT_combo`) using harmonized rotation‑scale inputs produced by
#' \code{prepare_shmi_inputs()}. SHMI is a weighted composite of four
#' sub‑indices:
#'
#' \itemize{
#'   \item \strong{Cover} — season‑weighted plant presence
#'   \item \strong{Diversity} — rotation‑scale crop diversity (Hill numbers)
#'   \item \strong{Inverse disturbance} — EPA mechanistic or STIR method
#'   \item \strong{Organic inputs} — amendments + animal integration
#' }
#'
#' By default, SHMI is computed using the official national settings
#' (“locked mode”). In expert mode, users may override any setting, but the
#' resulting SHMI values are no longer comparable to the national SHMI scale.
#'
#'
#' ## Required inputs
#'
#' The function expects a list returned by \code{prepare_shmi_inputs()} with:
#'
#' \itemize{
#'   \item \code{rot_bounds} — rotation start/end dates and rotation years
#'   \item \code{crop} — harmonized crop windows (one row per species)
#'   \item \code{dist} — disturbance events (EPA/STIR inputs)
#'   \item \code{amend} — amendment events
#'   \item \code{animal} — animal integration events
#'   \item \code{mgt} — management metadata (study, farm, field, treatment)
#' }
#'
#'
#' ## Disturbance method
#'
#' Disturbance can be computed using:
#'
#' \itemize{
#'   \item \code{"EPA"} — mechanistic soil‑mixing model (profile penetration)
#'   \item \code{"STIR"} — daily summed mixing efficiency (SD_mixeff)
#' }
#'
#' Both methods classify annual tillage intensity using the modified Tier‑3
#' Z–K scheme and compute inverse disturbance on a 0–100 scale.
#'
#'
#' ## Settings and expert mode
#'
#' In locked mode (\code{expert_mode = FALSE}), SHMI uses the official national
#' settings:
#'
#' \itemize{
#'   \item seasonal cover weights
#'   \item Hill‑number order and maximum diversity
#'   \item STIR normalization constant
#'   \item amendment/animal weights
#'   \item pillar weights for SHMI aggregation
#' }
#'
#' In expert mode, user‑supplied settings override defaults. Missing settings
#' are filled from the official values.
#'
#'
#' ## SHMI computation workflow
#'
#' \enumerate{
#'   \item \strong{Settings}: locked mode vs expert mode.
#'
#'   \item \strong{Input validation}: structural checks on all required inputs.
#'
#'   \item \strong{Pillar computation}:
#'     \itemize{
#'       \item Cover — \code{compute_cover()}
#'       \item Diversity — \code{compute_diversity()}
#'       \item Inverse disturbance — \code{compute_disturbance()}
#'       \item Organic inputs — \code{compute_orginput()}
#'     }
#'
#'   \item \strong{Weighted combination}:
#'     Pillar scores are normalized so weights sum to 1, then combined:
#'
#'     \deqn{
#'       SHMI =
#'         w_{cover} \cdot Cover +
#'         w_{div}   \cdot Diversity +
#'         w_{dist}  \cdot InvDist +
#'         w_{ani}   \cdot OrgInput
#'     }
#'
#'   \item \strong{Output assembly}:
#'     Returns a tidy data frame of SHMI scores and metadata describing the
#'     settings used, SHMI version, and computation timestamp.
#' }
#'
#'
#' @param shmi_inputs A list returned by \code{prepare_shmi_inputs()} containing
#'   harmonized rotation‑scale inputs (see Details).
#'
#' @param dist_meth Disturbance method: \code{"EPA"} or \code{"STIR"}.
#'
#' @param settings Optional named list of SHMI settings. Ignored unless
#'   \code{expert_mode = TRUE}.
#'
#' @param expert_mode Logical; if \code{TRUE}, user‑supplied settings override
#'   official defaults.
#'
#'
#' @return A list with:
#'   \itemize{
#'     \item \code{indicator_df} — data frame with:
#'       \code{MGT_combo}, \code{SHMI}, \code{Cover}, \code{Diversity},
#'       \code{InvDist}, \code{OrgInput}, and available metadata.
#'     \item \code{settings_used} — settings actually applied
#'     \item \code{expert_mode} — logical flag
#'     \item \code{shmi_version} — version string
#'     \item \code{timestamp} — computation time
#'   }
#'
#' @export
build_shmi <- function(shmi_inputs,
                       dist_meth = c("EPA", "STIR"),
                       settings = NULL,
                       expert_mode = FALSE) {

  dist_meth <- match.arg(dist_meth)

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
    w_winter = 0.157,
    w_spring = 0.159,
    w_summer = 0.463,
    w_fall   = 0.222,

    # diversity
    hill      = 1,
    max_div   = 8,

    # disturbance
    max_stir    = 299,

    # organic amendments
    w_amend   = 0.461,
    w_animals = 0.539,

    # shmi weights
    w_cover    = 0.670,
    w_div      = 0.082,
    w_dist     = 0.097,
    w_ani      = 0.151
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
  required <- c("rot_bounds", "crop", "dist", "amend", "animal")

  missing <- setdiff(required, names(shmi_inputs))
  if (length(missing) > 0) {
    stop(
      "Missing required inputs in shmi_inputs: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }

  mgt             <- shmi_inputs$mgt
  rot_bounds      <- shmi_inputs$rot_bounds
  crop            <- shmi_inputs$crop
  dist            <- shmi_inputs$dist
  amend           <- shmi_inputs$amend
  animal          <- shmi_inputs$animal

  # --------------------------------------------------------------------------
  # 4. Compute sub-indices
  # --------------------------------------------------------------------------

  # Cover
  cli::cli_progress_step("Computing cover...")
  cover <- compute_cover(
    crop        = crop,
    rot_bounds  = rot_bounds,
    w_winter    = settings$w_winter,
    w_spring    = settings$w_spring,
    w_summer    = settings$w_summer,
    w_fall      = settings$w_fall
  )

  # Diversity
  cli::cli_progress_step("Computing diversity...")
  diversity <- compute_diversity(
    crop      = crop,
    hill      = settings$hill,
    max_div   = settings$max_div
  )

  # Disturbance (inverse disturbance pillar)
  cli::cli_progress_step("Computing disturbance...")
  invdist <- compute_disturbance(
    dist          = dist,
    dist_meth   = dist_meth,
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

  # --------------------------------------------------------------------------
  # 5. Combine sub-indices
  # --------------------------------------------------------------------------
  cli::cli_progress_step("Combining indices...")
  indicator_df <- purrr::reduce(
    list(mgt, cover, diversity, invdist, orginput),
    dplyr::full_join,
    by = "MGT_combo"
  )

  w_sum   <- settings$w_cover + settings$w_div + settings$w_dist + settings$w_ani

  w_cover    <- settings$w_cover / w_sum
  w_div      <- settings$w_div   / w_sum
  w_dist     <- settings$w_dist  / w_sum
  w_ani      <- settings$w_ani   / w_sum

  indicator_df <- indicator_df %>%
    dplyr::mutate(
      SHMI = (
          w_cover * .data$Cover +
          w_div   * .data$Diversity +
          w_dist  * .data$InvDist +
          w_ani   * .data$OrgInput
      )
    ) %>%
    dplyr::select(any_of(c(
      "MGT_combo", "MGT_study", "MGT_farm",
      "MGT_field", "MGT_trt",
      "SHMI", "Cover", "Diversity",
      "InvDist", "OrgInput"
    ))) %>%
    dplyr::arrange(.data$MGT_combo)

  indicator_df <- indicator_df %>%
    filter(!is.na(SHMI))

  cli::cli_progress_done()
  cli::cli_progress_cleanup()

  if (!expert_mode) {
    message("\n\nSHMI computed using official national settings.")
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
