#' Monthly climate normals for SHMI's Cover seasons
#'
#' Extracts long-term monthly mean temperature and precipitation (WorldClim
#' 2.1, 1970-2000) at each location, in the form [compute_cover()] and
#' [build_shmi()] expect. Requires the `geodata` and `terra` packages. The
#' global WorldClim layers are downloaded once and kept in a persistent cache
#' ([shmi_climate_dir()]), so later calls, new R sessions and subprocesses
#' reuse them instead of downloading them again.
#'
#' @param locations Either the list returned by [prepare_shmi_inputs()], whose
#'   management units supply coordinates (`MGT_lat`, `MGT_lon`) and irrigation
#'   (`MGT_irr_cat`), or a data frame with `MGT_combo`, `lon` and `lat`
#'   (decimal degrees) and optionally `irrigated` (logical). Irrigated units
#'   ignore the dry-month rule.
#' @param res WorldClim resolution in arc-minutes: 10, 5 or 2.5 (finer means
#'   a larger download).
#' @param path Folder for the WorldClim files. Defaults to [shmi_climate_dir()],
#'   a persistent cache; files already there are reused.
#'
#' @return A tibble with `MGT_combo`, `tavg_01` ... `tavg_12` (C),
#'   `prec_01` ... `prec_12` (mm) and `irrigated`.
#'
#' @examples
#' \dontrun{
#' inputs  <- prepare_shmi_inputs(get_shmi_example())
#' climate <- get_shmi_climate(inputs)      # coordinates and irrigation from Mgt_Unit
#'
#' # or from a table of coordinates
#' locs <- data.frame(MGT_combo = c("farm1_trt1", "farm1_trt2"),
#'                    lon = -105.08, lat = 40.59, irrigated = c(FALSE, TRUE))
#' climate <- get_shmi_climate(locs)
#' }
#' @export
get_shmi_climate <- function(locations, res = 10, path = shmi_climate_dir()) {
  if (is.list(locations) && !is.data.frame(locations)) locations <- .climate_locations(locations)
  for (p in c("geodata", "terra"))
    if (!requireNamespace(p, quietly = TRUE))
      stop("get_shmi_climate() needs the '", p, "' package: install.packages(\"", p, "\")", call. = FALSE)
  need <- c("MGT_combo", "lon", "lat")
  miss <- setdiff(need, names(locations))
  if (length(miss)) stop("`locations` lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  tavg <- .worldclim_layer("tavg", res, path)
  prec <- .worldclim_layer("prec", res, path)
  pts <- cbind(locations$lon, locations$lat)
  t_m <- terra::extract(tavg, pts); p_m <- terra::extract(prec, pts)
  t_m <- as.matrix(t_m[, grep("tavg", names(t_m))]); p_m <- as.matrix(p_m[, grep("prec", names(p_m))])
  out <- tibble::tibble(MGT_combo = locations$MGT_combo)
  out[sprintf("tavg_%02d", 1:12)] <- as.data.frame(round(t_m, 2))
  out[sprintf("prec_%02d", 1:12)] <- as.data.frame(round(p_m, 1))
  out$irrigated <- if ("irrigated" %in% names(locations)) as.logical(locations$irrigated) else FALSE
  bad <- out$MGT_combo[rowSums(is.na(t_m)) > 0]
  if (length(bad)) warning("No WorldClim data at ", length(bad), " location(s) (e.g. on a coast): ",
                           paste(utils::head(bad, 5), collapse = ", "), call. = FALSE)
  out
}


#' Folder where SHMI keeps the WorldClim climate normals
#'
#' [get_shmi_climate()] downloads the global WorldClim 2.1 layers (about 43 MB
#' at 10 arc-minutes) the first time and reuses them afterwards. They are kept
#' in a persistent user cache, `tools::R_user_dir("SHMI", "cache")`, rather than
#' the session's temporary folder, so they survive between R sessions. Set
#' `options(shmi.climate_dir = "...")` or the environment variable
#' `SHMI_CLIMATE_DIR` to use another folder (for example a shared drive).
#'
#' @return The folder path (character). It is created by [get_shmi_climate()]
#'   when first needed.
#' @examples
#' shmi_climate_dir()
#' @export
shmi_climate_dir <- function() {
  p <- getOption("shmi.climate_dir", Sys.getenv("SHMI_CLIMATE_DIR", ""))
  if (is.null(p) || !nzchar(p)) p <- tools::R_user_dir("SHMI", which = "cache")
  file.path(p, "worldclim")
}

# One WorldClim layer: reused when already in `path`; otherwise downloaded with a
# longer timeout and one retry, and a clear message if both attempts fail.
.worldclim_layer <- function(var, res, path) {
  old <- options(timeout = max(600, getOption("timeout", 60)))
  on.exit(options(old), add = TRUE)
  last_err <- NULL
  for (attempt in 1:2) {
    r <- tryCatch(geodata::worldclim_global(var = var, res = res, path = path),
                  error = function(e) { last_err <<- conditionMessage(e); NULL })
    if (inherits(r, "SpatRaster")) return(r)
  }
  url <- sprintf("https://geodata.ucdavis.edu/climate/worldclim/2_1/base/wc2.1_%sm_%s.zip", res, var)
  stop("Could not download the WorldClim '", var, "' layer (", res, " arc-minutes) after two tries",
       if (!is.null(last_err)) paste0(": ", last_err) else "", ".\n",
       "Download it by hand from ", url, ", unzip it into ", file.path(path, "climate", paste0("wc2.1_", res, "m")),
       " and run get_shmi_climate() again; or set options(shmi.climate_dir = ...) to a folder that already has the files.",
       call. = FALSE)
}


# Coordinates and irrigation of each management unit in prepared inputs
.climate_locations <- function(shmi_inputs) {
  m <- shmi_inputs$mgt
  if (is.null(m)) stop("`locations` must be prepared inputs (with $mgt) or a data frame.", call. = FALSE)
  miss <- setdiff(c("MGT_lat", "MGT_lon"), names(m))
  if (length(miss))
    stop("Mgt_Unit has no ", paste(miss, collapse = " or "), " column: add latitude and longitude ",
         "(decimal degrees), or pass a data frame of MGT_combo, lon and lat.", call. = FALSE)
  lat <- suppressWarnings(as.numeric(m$MGT_lat)); lon <- suppressWarnings(as.numeric(m$MGT_lon))
  bad <- is.na(lat) | is.na(lon) | abs(lat) > 90 | abs(lon) > 180
  if (any(bad))
    stop(sum(bad), " management unit(s) lack valid coordinates (MGT_lat, MGT_lon in decimal degrees): ",
         paste(utils::head(m$MGT_combo[bad], 5), collapse = ", "), call. = FALSE)
  data.frame(MGT_combo = m$MGT_combo, lon = lon, lat = lat,
             irrigated = if ("irrigated" %in% names(m)) as.logical(m$irrigated) else FALSE,
             stringsAsFactors = FALSE)
}
