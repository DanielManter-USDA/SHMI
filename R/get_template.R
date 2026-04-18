#' Download a blank SHMI Excel template
#'
#' Saves the official SHMI Excel template to a user-specified path.
#' The template contains the required sheets and column names needed
#' to enter management data for SHMI computation.
#'
#' @details
#' This function copies the internal SHMI template (stored in
#' `inst/extdata/`) to a local file path. The template is intentionally
#' blank and must be filled in by the user before running
#' [`prepare_shmi_inputs()`]. Each sheet includes the required structure
#' for crop diversity, disturbance, organic inputs, and management units.
#'
#' @param path File path where the template should be saved.
#'
#' @return The path to the saved file (invisibly).
#'
#' @examples
#' \dontrun{
#' # Save template to working directory
#' download_shmi_template("SHMI_template.xlsx")
#'
#' # After filling in the Excel file:
#' inputs <- prepare_shmi_inputs("my_filled_template.xlsx")
#' result <- build_shmi(inputs)
#' }
#'
#' @seealso
#'   [download_shmi_example()], [get_shmi_example()],
#'   [prepare_shmi_inputs()], [build_shmi()]
#'
#' @family SHMI helper functions
#' @export
download_shmi_template <- function(path = "SHMI_template.xlsx") {
  template <- system.file("extdata", "SHMI_template.xlsx", package = "SHMI")
  file.copy(template, path, overwrite = TRUE)
  path
}


#' Download the example SHMI Excel file
#'
#' Saves a fully populated example SHMI Excel workbook to a user-specified
#' path. This file demonstrates the correct SHMI input structure and contains
#' realistic management data for testing the complete SHMI workflow.
#'
#' @details
#' The example file is stored internally in `inst/extdata/` and includes
#' valid entries for all required sheets (crop diversity, disturbance,
#' organic inputs, and management units). It is intended for:
#'
#' * testing the SHMI workflow end-to-end
#' * verifying installation and dependencies
#' * serving as a reference for how user-supplied data should be formatted
#'
#' Unlike the blank template provided by [`download_shmi_template()`],
#' this example file contains real data and can be passed directly to
#' [`prepare_shmi_inputs()`] without modification.
#'
#' @param path Directory where the example file should be saved.
#'
#' @return The path to the saved file (invisibly).
#'
#' @examples
#' \dontrun{
#' # Save example file to Desktop
#' download_shmi_example("~/Desktop")
#'
#' # Run the full SHMI workflow
#' example_file <- file.path("~/Desktop", "SHMI_example_1.xlsx")
#' inputs <- prepare_shmi_inputs(example_file)
#' result <- build_shmi(inputs)
#' head(result$indicator_df)
#' }
#'
#' @seealso
#'   [download_shmi_template()], [get_shmi_example()],
#'   [prepare_shmi_inputs()], [build_shmi()]
#'
#' @family SHMI helper functions
#' @export
download_shmi_example <- function(path = ".") {
  src <- system.file("extdata", "SHMI_example_1.xlsx", package = "SHMI")
  dest <- file.path(path, "SHMI_example_1.xlsx")
  file.copy(src, dest, overwrite = TRUE)
  invisible(dest)
}


#' Example SHMI dataset
#'
#' A small example dataset included with the SHMI package for demonstrating
#' the minimal R-native workflow:
#'
#' ```
#' data(shmi_example)
#' inputs <- prepare_shmi_inputs(shmi_example)
#' result <- build_shmi(inputs)
#' ```
#'
#' This dataset is a simplified, single-table representation of the SHMI
#' input structure. It is intended for quick examples, teaching, and
#' unit tests. For the full Excel-based workflow, use
#' [`download_shmi_example()`] or [`download_shmi_template()`].
#'
#' @format A data frame with X rows and Y variables:
#' \describe{
#'   \item{MGT_combo}{Management unit identifier}
#'   \item{date}{Calendar date}
#'   \item{CD_name}{Crop or mixture name}
#'   \item{crop_present}{1 if crop present, 0 otherwise}
#'   \item{SD_mixeff}{Mixing efficiency (if present)}
#'   \item{SD_depth_cm}{Tillage depth in cm (if present)}
#'   \item{...}{Additional variables depending on the example}
#' }
#'
#' @usage data(shmi_example)
#'
#' @seealso
#'   [prepare_shmi_inputs()], [build_shmi()],
#'   [download_shmi_example()], [download_shmi_template()]
#'
#' @family SHMI helper functions
"shmi_example"
