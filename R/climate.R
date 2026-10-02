#' Monthly climate normals for SHMI's Cover seasons
#'
#' Extracts long-term monthly mean temperature and precipitation (WorldClim
#' 2.1, 1970-2000) at each location, in the form [compute_cover()] and
#' [build_shmi()] expect. Requires the `geodata` and `terra` packages; the
#' global WorldClim layers are downloaded once to `path`.
#'
#' @param locations Either the list returned by [prepare_shmi_inputs()], whose
#'   management units supply coordinates (`MGT_lat`, `MGT_lon`) and irrigation
#'   (`MGT_irr_cat`), or a data frame with `MGT_combo`, `lon` and `lat`
#'   (decimal degrees) and optionally `irrigated` (logical). Irrigated units
#'   ignore the dry-month rule.
#' @param res WorldClim resolution in arc-minutes: 10, 5 or 2.5 (finer means
#'   a larger download).
#' @param path Folder for the downloaded WorldClim files.
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
get_shmi_climate <- function(locations, res = 10, path = file.path(tempdir(), "worldclim")) {
  if (is.list(locations) && !is.data.frame(locations)) locations <- .climate_locations(locations)
  for (p in c("geodata", "terra"))
    if (!requireNamespace(p, quietly = TRUE))
      stop("get_shmi_climate() needs the '", p, "' package: install.packages(\"", p, "\")", call. = FALSE)
  need <- c("MGT_combo", "lon", "lat")
  miss <- setdiff(need, names(locations))
  if (length(miss)) stop("`locations` lacks: ", paste(miss, collapse = ", "), call. = FALSE)
  dir.create(path, showWarnings = FALSE, recursive = TRUE)
  tavg <- geodata::worldclim_global(var = "tavg", res = res, path = path)
  prec <- geodata::worldclim_global(var = "prec", res = res, path = path)
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
