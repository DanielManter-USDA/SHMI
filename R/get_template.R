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
#' inputs  <- prepare_shmi_inputs("SHMI_template.xlsx")
#' climate <- get_shmi_climate(data.frame(MGT_combo = inputs$mgt$MGT_combo,
#'                                        lon = -105.08, lat = 40.59))
#' result  <- build_shmi(inputs, climate)
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
#' climate <- get_shmi_climate(data.frame(MGT_combo = inputs$mgt$MGT_combo,
#'                                        lon = -105.08, lat = 40.59))
#' result  <- build_shmi(inputs, climate)
#' head(result$indicator_df)
#' }
#'
#' @family SHMI helper functions
#' @seealso [prepare_shmi_inputs()], [build_shmi()]
#' @export
download_shmi_example <- function(path = ".", overwrite = TRUE) {
  src <- system.file("extdata", "SHMI_example.xlsx", package = "SHMI")
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
#' @return The path to `SHMI_example.xlsx` in the installed package.
#'
#' @examples
#' inputs <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
#'
#' # Monthly climate normals for each unit; get_shmi_climate() downloads these
#' # from WorldClim given coordinates. Typical temperate values, entered by hand:
#' climate <- data.frame(MGT_combo = inputs$mgt$MGT_combo)
#' climate[sprintf("tavg_%02d", 1:12)] <- as.list(c(-5, -3, 3, 10, 16, 21, 24, 23, 18, 11, 4, -2))
#' climate[sprintf("prec_%02d", 1:12)] <- as.list(c(20, 25, 50, 70, 110, 115, 95, 85, 70, 50, 35, 25))
#'
#' result <- build_shmi(inputs, climate)
#' result$indicator_df
#'
#' @family SHMI helper functions
#' @seealso [download_shmi_example()], [prepare_shmi_inputs()],
#'   [build_shmi()]
#' @export
get_shmi_example <- function() {
  path <- system.file("extdata", "SHMI_example.xlsx", package = "SHMI")
  if (!nzchar(path)) {
    stop("The SHMI example workbook was not found. Try reinstalling SHMI.",
         call. = FALSE)
  }
  path
}
