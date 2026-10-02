#' Official SHMI weights
#'
#' The weights of the four sub-indices in SHMI 1.0, the medians of 1,000
#' cross-validated calibration fits against measured soil health on 354 US
#' plots at 74 sites (NAPESHM). Within Cover, the growing season counts for
#' 0.860 and the non-growing season for 0.140 (see [compute_cover()]).
#'
#' @return A named numeric vector: `Cover`, `OrgInput`, `Diversity`,
#'   `InvDist`, summing to 1.
#' @examples
#' shmi_weights()
#' @export
shmi_weights <- function() {
  c(Cover = 0.400, OrgInput = 0.317, Diversity = 0.153, InvDist = 0.130)
}


#' Compute SHMI scores
#'
#' Computes the Soil Health Management Index (SHMI) for each management unit
#' (`MGT_combo`) from prepared inputs and monthly climate normals:
#' \deqn{SHMI = 0.400\,Cover + 0.317\,OrgInput + 0.153\,Diversity + 0.130\,InvDist}
#'
#' * **Cover**: share of days with living plants in the growing and
#'   non-growing seasons, set by each unit's climate ([compute_cover()]).
#' * **OrgInput**: share of years with an organic amendment or grazing
#'   animals ([compute_orginput()]).
#' * **Diversity**: average annual plant species richness
#'   ([compute_diversity()]).
#' * **InvDist**: inverse tillage disturbance, computed as in USDA's T-DISC
#'   from implement mixing efficiencies and depths, or from STIR
#'   ([compute_disturbance()]).
#'
#' Every sub-index and SHMI run from 0 to 100. A missing record means the
#' practice did not happen.
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()].
#' @param climate Monthly climate normals, one row per `MGT_combo`, with
#'   `tavg_01` ... `tavg_12` and `prec_01` ... `prec_12`.
#'   `get_shmi_climate(shmi_inputs)` builds it from the coordinates on
#'   Mgt_Unit. Irrigation comes from Mgt_Unit (`MGT_irr_cat`) unless the table
#'   has its own `irrigated` column.
#' @param weights Optional named vector of custom weights (`Cover`,
#'   `OrgInput`, `Diversity`, `InvDist`), rescaled to sum to 1. Scores with
#'   custom weights are not comparable to the official SHMI scale.
#' @param dist_meth Tillage scale: `"EPA"` (default; each pass's mixing
#'   efficiency and depth, or its implement's T-DISC values), `"STIR"` (STIR
#'   values), or `"auto"` (STIR for records holding only STIR values,
#'   otherwise EPA). Both are scored with T-DISC's crop intervals and windows.
#' @param implements Optional user implement table (`implement`,
#'   `mixing_efficiency`, `depth_cm`) overriding T-DISC's values for named
#'   implements; see [compute_disturbance()].
#'
#' @return A list with `indicator_df` (one row per unit: `MGT_combo`, any
#'   management metadata, `SHMI`, `Cover`, `OrgInput`, `Diversity`,
#'   `InvDist`, `Cover_growing`, `Cover_nongrowing`, `Richness`),
#'   `weights`, `dist_meth` (the tillage scale used), `official` (`TRUE`
#'   unless custom weights were used),
#'   `shmi_version` and `timestamp` (plus `expert_mode` and `settings_used`,
#'   kept for code written against SHMI < 1.0).
#'
#' @seealso [prepare_shmi_inputs()], [get_shmi_climate()], [shmi_components()],
#'   [plot_shmi_gauge()], [plot_shmi_lollipop()]
#'
#' @examples
#' \dontrun{
#' inputs  <- prepare_shmi_inputs("my_workbook.xlsx")
#' climate <- get_shmi_climate(inputs)
#' result  <- build_shmi(inputs, climate)
#' result$indicator_df
#' }
#' @export
build_shmi <- function(shmi_inputs, climate, weights = NULL, dist_meth = c("EPA", "STIR", "auto"),
                       implements = NULL) {
  dist_meth <- .resolve_dist_meth(shmi_inputs$dist, match.arg(dist_meth))
  cli::cli_progress_step("Validating inputs...")
  val <- validate_shmi_input(shmi_inputs, dist_meth = dist_meth)
  if (!val$ok) {
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run build_shmi().", call. = FALSE)
  }
  if (length(val$warnings)) message("Warnings:\n", paste0(" - ", val$warnings, collapse = "\n"))

  w <- shmi_weights(); official <- is.null(weights)
  if (!is.null(weights)) {
    if (is.null(names(weights)) || !setequal(names(weights), names(w)) ||
        any(!is.finite(weights)) || any(weights < 0) || sum(weights) <= 0)
      stop("`weights` must be non-negative numbers named Cover, OrgInput, Diversity and InvDist.", call. = FALSE)
    w <- weights[names(w)] / sum(weights)
    message("Custom weights: scores are not comparable to the official SHMI scale.")
  }

  cli::cli_progress_step("Computing sub-indices...")
  comp <- shmi_components(shmi_inputs, climate, dist_meth = dist_meth, implements = implements)

  cli::cli_progress_step("Combining...")
  indicator_df <- shmi_inputs$mgt %>%
    dplyr::select(dplyr::any_of(c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt", "irrigated"))) %>%
    dplyr::left_join(comp, by = "MGT_combo") %>%
    dplyr::mutate(SHMI = w[["Cover"]] * .data$Cover + w[["OrgInput"]] * .data$OrgInput +
                    w[["Diversity"]] * .data$Diversity + w[["InvDist"]] * .data$InvDist) %>%
    dplyr::relocate("SHMI", "Cover", "OrgInput", "Diversity", "InvDist", .after = dplyr::last_col()) %>%
    dplyr::relocate("Cover_growing", "Cover_nongrowing", "Richness", "TI_tillage", "tillage_designation",
                    .after = dplyr::last_col()) %>%
    dplyr::arrange(.data$MGT_combo)
  cli::cli_progress_done()

  list(indicator_df = indicator_df, weights = w, dist_meth = dist_meth, official = official,
       shmi_version = as.character(utils::packageVersion("SHMI")), timestamp = Sys.time(),
       # kept for code written against SHMI < 1.0 (e.g. plotting helpers)
       expert_mode = !official, settings_used = list(weights = w, dist_meth = dist_meth))
}
