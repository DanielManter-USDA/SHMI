#' SHMI: Soil Health Management Index
#'
#' The **SHMI** package provides a complete, reproducible workflow for computing
#' the Soil Health Management Index (SHMI) from standardized Excel workbooks.
#' SHMI is a composite indicator integrating four management pillars:
#'
#' \itemize{
#'   \item \strong{Cover} — seasonal plant presence
#'   \item \strong{Diversity} — rotation-scale crop diversity (Hill numbers)
#'   \item \strong{Inverse Disturbance} — mechanistic mixing-efficiency × depth metric
#'   \item \strong{Organic Inputs} — amendments and animal presence
#' }
#'
#' The package includes:
#'
#' \itemize{
#'   \item robust input validation and harmonization
#'   \item biologically realistic crop-window processing
#'   \item fast vectorized daily-grid construction
#'   \item mechanistic disturbance modeling
#'   \item rotation-scale aggregation
#'   \item official national SHMI settings (locked mode)
#'   \item expert-mode overrides for research and scenario analysis
#' }
#'
#' @section Workflow:
#'
#' A complete SHMI workflow consists of:
#'
#' \enumerate{
#'   \item \strong{Prepare inputs}
#'     \code{\link{prepare_shmi_inputs}()}
#'     Reads and validates the Excel workbook, harmonizes crop windows,
#'     constructs rotation bounds, and generates daily grids.
#'
#'   \item \strong{Compute SHMI}
#'     \code{\link{build_shmi}()}
#'     Computes all four pillars and combines them into a final SHMI score.
#'
#'   \item \strong{Interpret results}
#'     The returned object includes pillar scores, final SHMI values,
#'     settings used, and a timestamp for reproducibility.
#' }
#'
#' @section Settings:
#'
#' By default, SHMI is computed using the official national settings
#' (locked mode).
#' Setting \code{expert_mode = TRUE} allows users to override weights and
#' parameters, but resulting SHMI values are not comparable to the national
#' SHMI scale.
#'
#' @section Versioning and Reproducibility:
#'
#' All SHMI outputs include:
#' \itemize{
#'   \item \code{shmi_version} — version of the SHMI algorithm
#'   \item \code{timestamp} — computation time
#'   \item \code{settings_used} — full list of settings applied
#' }
#'
#' @section Key Functions:
#'
#' \itemize{
#'   \item \code{\link{prepare_shmi_inputs}} — read, validate, harmonize inputs
#'   \item \code{\link{build_shmi}} — compute SHMI scores
#'   \item \code{\link{compute_w.cover}} — cover pillar
#'   \item \code{\link{compute_rot_diversity}} — diversity pillar
#'   \item \code{\link{compute_avg_annual_disturbance}} — inverse disturbance pillar
#'   \item \code{\link{compute_orginput}} — organic inputs pillar
#' }
#'
#' @name SHMI
#' @aliases SHMI-package
NULL
