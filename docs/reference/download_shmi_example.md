# Download the example SHMI Excel file

Saves a fully populated example SHMI Excel workbook to a user-specified
path. This file demonstrates the correct SHMI input structure and
contains realistic management data for testing the complete SHMI
workflow.

## Usage

``` r
download_shmi_example(path = ".")
```

## Arguments

- path:

  Directory where the example file should be saved.

## Value

The path to the saved file (invisibly).

## Details

The example file is stored internally in \`inst/extdata/\` and includes
valid entries for all required sheets (crop diversity, disturbance,
organic inputs, and management units). It is intended for:

\* testing the SHMI workflow end-to-end \* verifying installation and
dependencies \* serving as a reference for how user-supplied data should
be formatted

Unlike the blank template provided by \[\`download_shmi_template()\`\],
this example file contains real data and can be passed directly to
\[\`prepare_shmi_inputs()\`\] without modification.

## See also

\[download_shmi_template()\], \[get_shmi_example()\],
\[prepare_shmi_inputs()\], \[build_shmi()\]

Other SHMI helper functions:
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md),
[`shmi_example`](https://danielmanter-usda.github.io/SHMI/reference/shmi_example.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Save example file to Desktop
download_shmi_example("~/Desktop")

# Run the full SHMI workflow
example_file <- file.path("~/Desktop", "SHMI_example_1.xlsx")
inputs <- prepare_shmi_inputs(example_file)
result <- build_shmi(inputs)
head(result$indicator_df)
} # }
```
