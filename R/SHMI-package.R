#' SHMI: Soil Health Management Index
#'
#' Computes the Soil Health Management Index (SHMI) from management records
#' entered in a standard Excel workbook. SHMI is a 0-100 composite of four
#' sub-indices:
#'
#' * **Cover**: season-weighted proportion of days with living plants.
#' * **Diversity**: rotation-scale crop diversity.
#' * **Inverse disturbance**: soil disturbance from tillage, by the EPA
#'   soil-mixing model or STIR.
#' * **Organic inputs**: organic amendments and animal integration.
#'
#' @section Workflow:
#' 1. [download_shmi_template()] provides a blank workbook, and
#'    [download_shmi_example()] a completed one; [get_shmi_example()] gives
#'    the path of the installed example.
#' 2. [prepare_shmi_inputs()] reads and validates the workbook, converts crop
#'    records into species episodes, and records every assumption it makes.
#' 3. [build_shmi()] computes the four sub-indices and SHMI.
#' 4. [plot_shmi_gauge()] and [plot_shmi_lollipop()] display the results.
#'
#' The sub-indices can also be computed directly with [compute_cover()],
#' [compute_diversity()], [compute_disturbance()], and [compute_orginput()].
#'
#' @section Design principles:
#' * **Missing records mean "did not happen".** No disturbance record means
#'   no disturbance (InvDist = 100); no crop means no cover; no amendment
#'   means no organic input.
#' * **The evaluation window is set by the data or by overrides.** Rotation
#'   bounds span the first to the last recorded event unless
#'   `start_date_override` / `end_date_override` are given to
#'   [prepare_shmi_inputs()].
#' * **Assumptions are reported, not hidden.** Every imputed date and every
#'   value that could not be converted is listed in
#'   `prepare_shmi_inputs()$assumptions`.
#'
#' @section Settings:
#' By default, [build_shmi()] uses the official national settings ("locked
#' mode"). With `expert_mode = TRUE`, weights and parameters can be changed,
#' but the resulting scores are not comparable to the national SHMI scale.
#' Each result records the settings used, the package version, and a
#' timestamp.
#'
#' @keywords internal
"_PACKAGE"
