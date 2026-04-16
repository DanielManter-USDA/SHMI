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
#'   [get_shmi_example()], [prepare_shmi_inputs()], [build_shmi()]
#'
#' @family SHMI helper functions
#' @export
download_shmi_template <- function(path = "SHMI_template.xlsx") {
  template <- system.file("extdata", "SHMI_template.xlsx", package = "SHMI")
  file.copy(template, path, overwrite = TRUE)
  path
}


#' Load the example SHMI Excel file
#'
#' Returns the path to a fully populated example Excel workbook that
#' demonstrates the correct SHMI input structure. This file contains
#' realistic management data and can be used to test the complete SHMI
#' workflow without entering data manually.
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
#' @return A file path (string) pointing to the example Excel file.
#'
#' @examples
#' \dontrun{
#' # Retrieve the example file
#' example_file <- get_shmi_example()
#'
#' # Run the full SHMI workflow
#' inputs <- prepare_shmi_inputs(example_file)
#' result <- build_shmi(inputs)
#' head(result$indicator_df)
#' }
#'
#' @seealso
#'   [download_shmi_template()], [prepare_shmi_inputs()], [build_shmi()]
#'
#' @family SHMI helper functions
#' @export
get_shmi_example <- function() {
  system.file("extdata", "SHMI_example_1.xlsx", package = "SHMI")
}
