#' Official SHMI weights
#'
#' The weights of the three sub-indices in SHMI_base, the medians of 1,000
#' cross-validated calibration fits against measured soil health on 354 US
#' plots at 74 sites (NAPESHM). Diversity's weight was fixed at 0.150 and the
#' other two fitted under that constraint. Within Cover/Roots, the growing season
#' counts 0.760 and the non-growing season 0.240 (see [compute_cover()]).
#' Organic amendments are not weighted: they raise SHMI_base to SHMI (see
#' [shmi_parameters()] and [build_shmi()]).
#'
#' @return A named numeric vector: `Cover`, `Diversity`, `InvDist`, summing
#'   to 1.
#' @seealso [shmi_parameters()]
#' @examples
#' shmi_weights()
#' @export
shmi_weights <- function() {
  c(Cover = 0.687, Diversity = 0.150, InvDist = 0.163)
}


#' Official SHMI parameters
#'
#' Every calibrated constant used by [build_shmi()]:
#'
#' * `weights`: the sub-index weights ([shmi_weights()]).
#' * `growing_share`: weight of the growing season within Cover/Roots (0.760).
#' * `graze_gap`: share of the gap to 100 in Diversity closed by grazing
#'   animals in every year (0.25). Grazing in a share \eqn{p_{animal}} of years
#'   gives \eqn{Diversity = D_{plants} + 0.25\,p_{animal}(100 - D_{plants})}.
#' * `amend_gap`: share of the gap to 100 in SHMI_base closed by an organic
#'   amendment in every year (0.60). Amendments in a share \eqn{p_{amend}} of
#'   years give \eqn{SHMI = SHMI_{base} + 0.60\,p_{amend}(100 - SHMI_{base})}.
#'
#' Both gap terms close part of the distance to 100, so no score exceeds 100,
#' and a low score gains more than a high one.
#'
#' @return A list with `weights`, `growing_share`, `graze_gap` and
#'   `amend_gap`.
#' @seealso [shmi_weights()], [build_shmi()]
#' @examples
#' shmi_parameters()
#' @export
shmi_parameters <- function() {
  list(weights = shmi_weights(), growing_share = 0.760, graze_gap = 0.25, amend_gap = 0.60)
}


#' Compute SHMI scores
#'
#' Computes two scores for each management unit (`MGT_combo`) from prepared
#' inputs and monthly climate normals:
#' \deqn{SHMI_{base} = 0.687\,Cover + 0.150\,Diversity + 0.163\,InvDist}
#' \deqn{SHMI = SHMI_{base} + 0.60\,p_{amend}\,(100 - SHMI_{base})}
#'
#' * **Cover/Roots** (column `Cover`): share of days with plants present in
#'   the growing and non-growing seasons, set by each unit's climate
#'   ([compute_cover()]).
#' * **Diversity**: plant species richness over 4-year spans
#'   ([compute_diversity()]), raised by grazing animals: grazing in a share
#'   \eqn{p_{animal}} of years closes \eqn{0.25\,p_{animal}} of the gap to 100.
#' * **Inverse Disturbance** (column `InvDist`): inverse tillage disturbance, computed as in USDA's T-DISC
#'   from implement mixing efficiencies and depths, or from STIR
#'   ([compute_disturbance()]).
#' * **SHMI** adds the amendment bonus, `Amend_bonus`, to `SHMI_base`:
#'   organic amendments in a share \eqn{p_{amend}} of years close
#'   \eqn{0.60\,p_{amend}} of the gap between SHMI_base and 100. SHMI_base
#'   describes the field's own plant and tillage management; SHMI adds carbon
#'   brought in from outside. SHMI is the calibrated score; a unit without
#'   amendments has SHMI = SHMI_base.
#'
#' Every sub-index and both scores run from 0 to 100. A missing record means
#' the practice did not happen.
#'
#' @param shmi_inputs A list returned by [prepare_shmi_inputs()].
#' @param climate Monthly climate normals, one row per `MGT_combo`, with
#'   `tavg_01` ... `tavg_12` and `prec_01` ... `prec_12`.
#'   `get_shmi_climate(shmi_inputs)` builds it from the coordinates on
#'   Mgt_Unit. Irrigation comes from Mgt_Unit (`MGT_irr_cat`) unless the table
#'   has its own `irrigated` column.
#' @param weights Optional named vector of custom weights (`Cover`,
#'   `Diversity`, `InvDist`), rescaled to sum to 1.
#' @param dist_meth Tillage scale: `"EPA"` (default; each pass's mixing
#'   efficiency and depth, or its implement's T-DISC values), `"STIR"` (STIR
#'   values), or `"auto"` (STIR for records holding only STIR values,
#'   otherwise EPA). Both are scored with T-DISC's crop intervals and windows.
#' @param implements Optional user implement table (`implement`,
#'   `mixing_efficiency`, `depth_cm`) overriding T-DISC's values for named
#'   implements; see [compute_disturbance()].
#' @param growing_share,graze_gap,amend_gap Optional custom values of the
#'   calibrated constants (see [shmi_parameters()]), each between 0 and 1.
#'   Scores computed with any custom weight or constant are flagged
#'   `official = FALSE` and are not comparable to the official scale.
#'
#' @return A list with `indicator_df` (one row per unit: `MGT_combo`, any
#'   management metadata, `SHMI`, `SHMI_base`, `Amend_bonus`, `Cover`,
#'   `Diversity`, `InvDist`, then `Cover_growing`, `Cover_nongrowing`,
#'   `Diversity_plants` (before the grazing credit), `Richness`, `p_amend`,
#'   `p_animal`, `TI_tillage` and `tillage_designation`), `weights`,
#'   `parameters` (all constants used), `dist_meth` (the tillage scale used),
#'   `official` (`TRUE` unless a custom weight or constant was used),
#'   `shmi_version` and `timestamp`.
#'
#' @seealso [prepare_shmi_inputs()], [get_shmi_climate()], [shmi_components()],
#'   [shmi_parameters()], [plot_shmi_gauge()], [plot_shmi_lollipop()]
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
                       implements = NULL, growing_share = NULL, graze_gap = NULL, amend_gap = NULL) {
  dist_meth <- .resolve_dist_meth(shmi_inputs$dist, match.arg(dist_meth))
  par <- shmi_parameters(); w <- par$weights
  official <- is.null(weights) && is.null(growing_share) && is.null(graze_gap) && is.null(amend_gap)
  if (!is.null(weights)) {
    if ("OrgInput" %in% names(weights))
      stop("OrgInput is no longer a weighted sub-index: organic amendments raise SHMI_base to SHMI ",
           "(`amend_gap`) and grazing raises Diversity (`graze_gap`). Give weights for Cover, ",
           "Diversity and InvDist.", call. = FALSE)
    if (is.null(names(weights)) || !setequal(names(weights), names(w)) ||
        any(!is.finite(weights)) || any(weights < 0) || sum(weights) <= 0)
      stop("`weights` must be non-negative numbers named Cover, Diversity and InvDist.", call. = FALSE)
    w <- weights[names(w)] / sum(weights)
  }
  for (k in c("growing_share", "graze_gap", "amend_gap")) {
    v <- get(k)
    if (is.null(v)) next
    if (!is.numeric(v) || length(v) != 1 || !is.finite(v) || v < 0 || v > 1)
      stop("`", k, "` must be a single number between 0 and 1.", call. = FALSE)
    par[[k]] <- v
  }
  par$weights <- w
  if (!official) message("Custom weights or constants: scores are not comparable to the official SHMI scale.")

  cli::cli_progress_step("Validating inputs...")
  val <- validate_shmi_input(shmi_inputs, dist_meth = dist_meth)
  if (!val$ok) {
    message("Errors:\n", paste0(" - ", val$errors, collapse = "\n"))
    stop("Fix the errors above and re-run build_shmi().", call. = FALSE)
  }
  if (length(val$warnings)) message("Warnings:\n", paste0(" - ", val$warnings, collapse = "\n"))

  cli::cli_progress_step("Computing sub-indices...")
  comp <- shmi_components(shmi_inputs, climate, dist_meth = dist_meth, implements = implements,
                          growing_share = par$growing_share, graze_gap = par$graze_gap)

  cli::cli_progress_step("Combining...")
  indicator_df <- shmi_inputs$mgt %>%
    dplyr::select(dplyr::any_of(c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt", "irrigated"))) %>%
    dplyr::left_join(comp, by = "MGT_combo") %>%
    dplyr::mutate(SHMI_base = w[["Cover"]] * .data$Cover + w[["Diversity"]] * .data$Diversity +
                    w[["InvDist"]] * .data$InvDist,
                  Amend_bonus = .amend_bonus(.data$SHMI_base, .data$p_amend, par$amend_gap),
                  SHMI = .data$SHMI_base + .data$Amend_bonus) %>%
    dplyr::relocate("SHMI", "SHMI_base", "Amend_bonus", "Cover", "Diversity", "InvDist",
                    .after = dplyr::last_col()) %>%
    dplyr::relocate("Cover_growing", "Cover_nongrowing", "Diversity_plants", "Richness",
                    "p_amend", "p_animal", "TI_tillage", "tillage_designation",
                    .after = dplyr::last_col()) %>%
    dplyr::arrange(.data$MGT_combo)
  cli::cli_progress_done()

  list(indicator_df = indicator_df, weights = w, parameters = par, dist_meth = dist_meth,
       official = official,
       shmi_version = as.character(utils::packageVersion("SHMI")), timestamp = Sys.time())
}


# Gap terms: close a share of the distance to 100. With x and share in
# [0, 100] and [0, 1], the result stays in [x, 100].
.grazing_credit <- function(diversity, p_animal, graze_gap = shmi_parameters()$graze_gap)
  diversity + graze_gap * p_animal * (100 - diversity)

.amend_bonus <- function(shmi_base, p_amend, amend_gap = shmi_parameters()$amend_gap)
  amend_gap * p_amend * (100 - shmi_base)
