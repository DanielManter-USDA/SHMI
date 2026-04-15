#' Get the SHMI Excel template
#'
#' Copies the SHMI Excel template to a user-specified location.
#'
#' @param path File path where the template should be saved.
#' @return The path to the saved file.
#' @export
get_shmi_template <- function(path = "SHMI_template.xlsx") {
  template <- system.file("extdata", "SHMI_template.xlsx", package = "SHMI")
  file.copy(template, path, overwrite = TRUE)
  path
}


#' Load the example SHMI Excel file
#'
#' Provides a fully populated example dataset for testing the SHMI workflow.
#'
#' @return The path to the example Excel file.
#' @export
get_shmi_example <- function() {
  system.file("extdata", "SHMI_example_1.xlsx", package = "SHMI")
}


#' Copy the example SHMI Excel file to a local path
#'
#' @param path File path to save the example.
#' @return The path to the saved file.
#' @export
copy_shmi_example <- function(path = "SHMI_example_1.xlsx") {
  example <- system.file("extdata", "SHMI_example_1.xlsx", package = "SHMI")
  file.copy(example, path, overwrite = TRUE)
  path
}
