#' Download a blank SHMI Excel template
#'
#' Saves the official, blank SHMI Excel template to a file.
#'
#' @details
#' The template contains the sheets and columns that
#' [prepare_shmi_inputs()] expects: management units, crop diversity, soil
#' disturbance, soil amendments, and animal diversity. Fill it in, then pass
#' the file to [prepare_shmi_inputs()].
#'
#' @param path File path for the template. Defaults to
#'   `"SHMI_template.xlsx"` in the working directory.
#' @param overwrite Logical. Overwrite an existing file?
#'
#' @return The path of the saved file, invisibly.
#'
#' @examples
#' \dontrun{
#' download_shmi_template("SHMI_template.xlsx")
#'
#' # After filling in the template:
#' inputs <- prepare_shmi_inputs("SHMI_template.xlsx")
#' result <- build_shmi(inputs)
#' }
#'
#' @family SHMI helper functions
#' @seealso [prepare_shmi_inputs()], [build_shmi()]
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


#' Download the example SHMI Excel workbook
#'
#' Saves a completed example SHMI workbook, `SHMI_example.xlsx`, to a
#' directory.
#'
#' @details
#' The example contains valid entries for every sheet and can be passed
#' straight to [prepare_shmi_inputs()]. Use it to test an installation, to
#' try the full workflow, or as a reference for formatting your own data.
#' To use the installed copy without saving a file, see
#' [get_shmi_example()].
#'
#' @param path Directory in which to save `SHMI_example.xlsx`. Defaults to the
#'   working directory.
#' @param overwrite Logical. Overwrite an existing file?
#'
#' @return The path of the saved file, invisibly.
#'
#' @examples
#' \dontrun{
#' my_file <- download_shmi_example()
#' inputs  <- prepare_shmi_inputs(my_file)
#' result  <- build_shmi(inputs)
#' head(result$indicator_df)
#' }
#'
#' @family SHMI helper functions
#' @seealso [prepare_shmi_inputs()], [build_shmi()]
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


#' Path to the example SHMI workbook
#'
#' Returns the path of the completed example workbook installed with the
#' package, so the full workflow can be run without downloading or copying
#' anything.
#'
#' @details
#' The workbook holds eight management units from one long-term experiment
#' (2020-2024): continuous corn and a crop rotation under several nitrogen
#' and manure treatments, with crop, disturbance (EPA mixing efficiencies and
#' tillage depths), and amendment records. It runs under the official
#' settings. To get a copy you can open in Excel, use
#' [download_shmi_example()].
#'
#' @return The path to `SHMI_example_1.xlsx` in the installed package.
#'
#' @examples
#' inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#' result <- build_shmi(inputs)
#' result$indicator_df
#'
#' @family SHMI helper functions
#' @seealso [download_shmi_example()], [prepare_shmi_inputs()],
#'   [build_shmi()]
#' @export
get_shmi_example <- function() {
  path <- system.file("extdata", "SHMI_example_1.xlsx", package = "SHMI")
  if (!nzchar(path)) {
    stop("The SHMI example workbook was not found. Try reinstalling SHMI.",
         call. = FALSE)
  }
  path
}
