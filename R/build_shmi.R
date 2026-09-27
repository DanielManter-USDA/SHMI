#' Compute SHMI scores from prepared inputs
#'
#' Computes the Soil Health Management Index (SHMI) for each management unit
#' (`MGT_combo`) from the rotation-scale inputs returned by
#' [prepare_shmi_inputs()]. SHMI is a weighted mean of four sub-indices, each
#' scaled 0-100:
#'
#' * **Cover**: season-weighted proportion of days with living plants
#'   ([compute_cover()]).
#' * **Diversity**: rotation-scale crop diversity ([compute_diversity()]).
#' * **InvDist**: inverse soil disturbance ([compute_disturbance()]).
#' * **OrgInput**: organic amendments and animal integration
#'   ([compute_orginput()]).
#'
#' @section Settings and expert mode:
#' With `expert_mode = FALSE` (the default, "locked mode") the official
#' national settings below are always used and `settings` is ignored. With
#' `expert_mode = TRUE`, each element of `settings` replaces the official
#' value; elements not supplied keep their official value. Expert-mode scores
#' are not comparable to the national SHMI scale.
#'
#' | Setting | Official value | Used by |
#' |---|---|---|
#' | `w_winter`, `w_spring`, `w_summer`, `w_fall` | 0.1259, 0.1260, 0.3755, 0.3726 | [compute_cover()] |
#' | `hill`, `max_div` | 1, 10 | [compute_diversity()] |
#' | `dist_meth`, `max_stir`, `ti_rep` | `"EPA"`, 342, `"max"` | [compute_disturbance()] |
#' | `w_amend`, `w_animal` | 0.6615, 0.3385 | [compute_orginput()] |
#' | `w_cover`, `w_diversity`, `w_invdist`, `w_orginput` | 0.4481, 0.0904, 0.1431, 0.3184 | SHMI |
#'
#' The four pillar weights are rescaled to sum to 1 and combined as
#' \deqn{SHMI = w_{cover} Cover + w_{diversity} Diversity + w_{invdist} InvDist + w_{orginput} OrgInput}
#'
#' The official disturbance method, `"EPA"`, requires a tillage depth
#' (`SD_depth`) for every pass. Data without depths can be scored in expert
#' mode with `settings = list(dist_meth = "STIR")`.
#'
#' @section Missing records:
#' Every management unit in `shmi_inputs$mgt` receives a score. A missing
#' record means the practice did not happen: a unit with no crops scores
#' Cover = 0 and Diversity = 0, no disturbance scores InvDist = 100, and no
#' organic inputs scores OrgInput = 0. Units with no dated records at all are
#' removed earlier, by [prepare_shmi_inputs()].
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()].
#' @param settings Optional named list of settings (see *Settings and expert
#'   mode*). Ignored unless `expert_mode = TRUE`.
#' @param expert_mode Logical. If `TRUE`, elements of `settings` override the
#'   official national settings.
#'
#' @return A list with:
#' * `indicator_df`: one row per management unit with `MGT_combo`, the
#'   management metadata that is present (`MGT_study`, `MGT_farm`,
#'   `MGT_field`, `MGT_trt`), `SHMI`, `Cover`, `Diversity`, `InvDist`, and
#'   `OrgInput`.
#' * `settings_used`: the full list of settings applied.
#' * `expert_mode`: logical flag.
#' * `shmi_version`: version of the SHMI package used.
#' * `timestamp`: time of computation.
#'
#' @seealso [prepare_shmi_inputs()], [validate_shmi_input()],
#'   [plot_shmi_gauge()], [plot_shmi_lollipop()]
#'
#' @examples
#' inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#'
#' # Official national settings
#' result <- build_shmi(inputs)
#' result$indicator_df
#'
#' # Expert mode: STIR disturbance, for data without tillage depths
#' \dontrun{
#' result_stir <- build_shmi(inputs, settings = list(dist_meth = "STIR"),
#'                           expert_mode = TRUE)
#' }
#'
#' @export
build_shmi <- function(shmi_inputs,
                       settings = NULL,
                       expert_mode = FALSE) {

  cli::cli_progress_step("Validating inputs...")

  # --------------------------------------------------------------------------
  # 1. Official national SHMI settings (locked mode)
  # --------------------------------------------------------------------------
  official <- list(
    # cover
    w_winter = 0.1259,
    w_spring = 0.1260,
    w_summer = 0.3755,
    w_fall   = 0.3726,

    # diversity
    hill      = 1,
    max_div   = 10,

    # disturbance
    dist_meth = "EPA",
    max_stir  = 342,
    ti_rep    = "max",

    # organic amendments
    w_amend  = 0.6615,
    w_animal = 0.3385,

    # shmi weights
    w_cover      = 0.4481,
    w_diversity  = 0.0904,
    w_invdist    = 0.1431,
    w_orginput   = 0.3184
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

  val <- validate_shmi_input(shmi_inputs, dist_meth = settings$dist_meth)

  if (!val$ok) {
    message("SHMI input validation failed.\n")
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run build_shmi().", call. = FALSE)
  }
  if (length(val$warnings) > 0) {
    message("\nWarnings:\n", paste0(" - ", val$warnings, collapse = "\n"))
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
    rot_bounds    = rot_bounds,
    dist_meth     = settings$dist_meth,
    max_stir      = settings$max_stir,
    ti_rep        = settings$ti_rep
  )

  # Organic inputs (amendments + animals)
  cli::cli_progress_step("Computing organic inputs...")
  orginput <- compute_orginput(
    rot_bounds  = rot_bounds,
    amend       = amend,
    animal      = animal,
    w_amend     = settings$w_amend,
    w_animal    = settings$w_animal
  )

  # --------------------------------------------------------------------------
  # 5. Combine sub-indices
  # --------------------------------------------------------------------------
  cli::cli_progress_step("Combining indices...")

  # Ensure all pillars contain all MGT_combo values
  all_sites <- mgt %>% dplyr::distinct(MGT_combo)

  cover     <- all_sites %>% left_join(cover,     by = "MGT_combo") %>%
    mutate(Cover     = replace_na(Cover,     0))

  diversity <- all_sites %>% left_join(diversity, by = "MGT_combo") %>%
    mutate(Diversity = replace_na(Diversity, 0))

  invdist   <- all_sites %>% left_join(invdist,   by = "MGT_combo") %>%
    mutate(InvDist   = replace_na(InvDist,   100))

  orginput  <- all_sites %>% left_join(orginput,  by = "MGT_combo") %>%
    mutate(OrgInput  = replace_na(OrgInput,  0))

  indicator_df <- purrr::reduce(
    list(mgt, cover, diversity, invdist, orginput),
    dplyr::full_join,
    by = "MGT_combo"
  )

  w_sum   <- settings$w_cover + settings$w_diversity + settings$w_invdist + settings$w_orginput

  w_cover     <- settings$w_cover     / w_sum
  w_diversity <- settings$w_diversity / w_sum
  w_invdist   <- settings$w_invdist   / w_sum
  w_orginput  <- settings$w_orginput  / w_sum

  indicator_df <- indicator_df %>%
    dplyr::mutate(
      SHMI = (
          w_cover     * .data$Cover +
          w_diversity * .data$Diversity +
          w_invdist   * .data$InvDist +
          w_orginput  * .data$OrgInput
      )
    ) %>%
    dplyr::select(any_of(c(
      "MGT_combo", "MGT_study", "MGT_farm",
      "MGT_field", "MGT_trt",
      "SHMI", "Cover", "Diversity",
      "InvDist", "OrgInput"
    ))) %>%
    dplyr::arrange(.data$MGT_combo)

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
    shmi_version  = as.character(utils::packageVersion("SHMI")),
    timestamp     = Sys.time()
  )
}
