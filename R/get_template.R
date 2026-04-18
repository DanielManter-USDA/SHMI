#' Download a blank SHMI Excel template
#'
#' Saves the official SHMI Excel template to a user-specified file path.
#' The template contains the required sheets and column names needed
#' to enter management data for SHMI computation.
#'
#' @details
#' This function copies the internal SHMI template (stored in
#' `inst/extdata/`) to a local file path. The template is intentionally
#' blank and must be filled in by the user before running
#' [`prepare_shmi_inputs()`]. It includes the required structure for
#' crop diversity, disturbance, organic inputs, and management units.
#'
#' @param path Full file path where the template should be saved.
#'   Defaults to `"SHMI_template.xlsx"` in the current working directory.
#' @param overwrite Logical. Overwrite the file if it already exists?
#'
#' @return The path to the saved file (invisibly).
#'
#' @examples
#' \dontrun{
#' # Save template to working directory
#' download_shmi_template("SHMI_template.xlsx")
#'
#' # Save to a specific folder
#' download_shmi_template(path = "~/Desktop/SHMI_template.xlsx")
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
download_shmi_template <- function(path = "SHMI_template.xlsx", overwrite = TRUE) {
  src <- system.file("extdata", "SHMI_template.xlsx", package = "SHMI")
  dest <- path.expand(path)

  if (file.copy(src, dest, overwrite = overwrite)) {
    message(paste("Blank SHMI template saved to:", normalizePath(dest)))
  } else {
    stop("Error: Could not save the template. Check your folder permissions.")
  }

  invisible(dest)
}


#' Download the example SHMI Excel file
#'
#' Saves a fully populated example SHMI Excel workbook to a user-specified
#' directory. This file demonstrates the correct SHMI input structure and
#' contains realistic management data for testing the complete SHMI workflow.
#'
#' @details
#' The example file is stored internally in `inst/extdata/` and includes valid
#' entries for all required sheets (crop diversity, disturbance, organic inputs,
#' and management units). It is intended for:
#'
#' * testing the SHMI workflow end-to-end
#' * verifying installation and dependencies
#' * serving as a reference for how user-supplied data should be formatted
#'
#' Unlike the blank template provided by [`download_shmi_template()`], this
#' example file contains real data and can be passed directly to
#' [`prepare_shmi_inputs()`] without modification.
#'
#' @param path Directory where the example file should be saved.
#'   Defaults to the current working directory (`"."`).
#' @param overwrite Logical. Overwrite the file if it already exists?
#'
#' @return The path to the saved file (invisibly).
#'
#' @examples
#' \dontrun{
#' # Save example file to your working directory
#' my_file <- download_shmi_example()
#'
#' # Run the full SHMI workflow
#' inputs <- prepare_shmi_inputs(my_file)
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
download_shmi_example <- function(path = ".", overwrite = TRUE) {
  src <- system.file("extdata", "SHMI_example_1.xlsx", package = "SHMI")
  dest <- file.path(path.expand(path), "SHMI_example.xlsx")

  if (file.copy(src, dest, overwrite = overwrite)) {
    message(paste("File 'SHMI_example.xlsx' has been created at:",
                  normalizePath(dest)))
  } else {
    stop("Error: Could not save the file. Check your folder permissions.")
  }

  invisible(dest)
}
