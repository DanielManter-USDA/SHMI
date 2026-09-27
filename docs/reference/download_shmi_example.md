# Download the example SHMI Excel workbook

Saves a completed example SHMI workbook, `SHMI_example.xlsx`, to a
directory.

## Usage

``` r
download_shmi_example(path = ".", overwrite = TRUE)
```

## Arguments

- path:

  Directory in which to save `SHMI_example.xlsx`. Defaults to the
  working directory.

- overwrite:

  Logical. Overwrite an existing file?

## Value

The path of the saved file, invisibly.

## Details

The example contains valid entries for every sheet and can be passed
straight to
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md).
Use it to test an installation, to try the full workflow, or as a
reference for formatting your own data. To use the installed copy
without saving a file, see
[`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md).

## See also

[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

Other SHMI helper functions:
[`download_shmi_template()`](https://danielmanter-usda.github.io/SHMI/reference/download_shmi_template.md),
[`get_shmi_example()`](https://danielmanter-usda.github.io/SHMI/reference/get_shmi_example.md)

## Examples

``` r
if (FALSE) { # \dontrun{
my_file <- download_shmi_example()
inputs  <- prepare_shmi_inputs(my_file)
result  <- build_shmi(inputs)
head(result$indicator_df)
} # }
```
