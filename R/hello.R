# Initial Setup of SHMI package

usethis::use_git()
usethis::use_github()

usethis::use_package_doc()
usethis::use_readme_rmd()
usethis::use_testthat()
usethis::use_vignette("SHMI-overview")

# now make files...
# R/build_shmi.R
# R/predict_sh.R
# R/utils.R


devtools::document()


#usethis::use_data(final_model, overwrite = TRUE)

devtools::check()
devtools::install()

