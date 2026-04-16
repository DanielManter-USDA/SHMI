# Load the example SHMI Excel file

Returns the path to a fully populated example Excel workbook that
demonstrates the correct SHMI input structure. This file contains
realistic management data and can be used to test the complete SHMI
workflow without entering data manually.

## Usage

``` r
get_shmi_example()
```

## Value

A file path (string) pointing to the example Excel file.

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

\[download_shmi_template()\], \[prepare_shmi_inputs()\],
\[build_shmi()\]

Other SHMI helper functions:
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Retrieve the example file
example_file <- get_shmi_example()

# Run the full SHMI workflow
inputs <- prepare_shmi_inputs(example_file)
result <- build_shmi(inputs)
head(result$indicator_df)
} # }
```
