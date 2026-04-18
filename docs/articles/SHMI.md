# Soil Health Management Index (SHMI)

Weighted Composite of Four Management Sub-indices

## **Overview**

The Soil Health Management Index (SHMI) integrates four management
indices—**Cover**, **Diversity**, **Inverse Disturbance**, and
**Animals**—into a single 0–100 score. Each pillar is computed from
harmonized rotation‑scale inputs and then combined using **official
national SHMI weights** (locked mode) or user‑specified weights (expert
mode).

SHMI is designed to be:

- **Mechanistic** (built from daily and annual process‑based inputs)  
- **Rotation‑scale** (not single‑year snapshots)  
- **Comparable across systems** (locked mode)  
- **Flexible for research** (expert mode)

------------------------------------------------------------------------

## **1. Settings**

SHMI can be computed in two modes:

### **Locked mode (default)**

Uses official national SHMI settings:

- Seasonal cover weights  
- Hill number and max diversity  
- Amendment/animal weights  
- Sub-index weights

User‑supplied settings are ignored.

### **Expert mode**

User settings override defaults.  
Resulting SHMI values are **not** comparable to the national scale.

------------------------------------------------------------------------

## **2. Input Validation**

Before any computation, the input list from
[`prepare_shmi_inputs()`](https://danielmanter-usda.github.io/SHMI/reference/prepare_shmi_inputs.md)
is validated:

- Required tables present  
- Required columns present  
- Valid date formats  
- No duplicated daily rows  
- No missing `MGT_combo`  
- Harmonized crop windows consistent

If validation fails, SHMI computation stops with explicit error
messages.

------------------------------------------------------------------------

## **3. Sub-index Computation**

Each pillar is computed using its dedicated sub‑index function:

- **Cover**  
  $`\text{Cover}_i = \text{compute_cover}(...)`$

- **Diversity**  
  $`\text{Diversity}_i = \text{compute_diversity}(...)`$

- **Inverse Disturbance**  
  $`\text{InvDist}_i = \text{compute_disturbance}(...)`$

- **Organic Inputs (Animals + Amendments)**  
  $`\text{Animals}_i = \text{compute_orginput}(...)`$

Each sub‑index is already scaled to **0–100**.

------------------------------------------------------------------------

## **4. Weighted Combination**

Let the four sub‑indices for management unit $`i`$ be:

- $`C_i`$ = Cover  
- $`D_i`$ = Diversity  
- $`I_i`$ = Inverse Disturbance  
- $`A_i`$ = Animals

Let the pillar weights be:

- $`w_{\text{cover}}`$  
- $`w_{\text{div}}`$  
- $`w_{\text{dist}}`$  
- $`w_{\text{ani}}`$

Weights are normalized:

``` math

w_s^{*} = \frac{w_s}{w_{\text{cover}} + w_{\text{div}} + w_{\text{dist}} + w_{\text{ani}}}
```

The final SHMI score is:

``` math

\text{SHMI}_i =
w_{\text{cover}}^{*} C_i +
w_{\text{div}}^{*} D_i +
w_{\text{dist}}^{*} I_i +
w_{\text{ani}}^{*} A_i
```

By construction:

``` math

0 \le \text{SHMI}_i \le 100
```

------------------------------------------------------------------------

## **5. Output Assembly**

The final output is a tidy data frame:

| MGT_combo | SHMI  | Cover | Diversity | InvDist | Animals |
|:---------:|:-----:|:-----:|:---------:|:-------:|:-------:|
|     …     | 0–100 | 0–100 |   0–100   |  0–100  |  0–100  |

Additional metadata returned:

- `settings_used` — actual settings applied  
- `expert_mode` — TRUE/FALSE  
- `shmi_version` — version string  
- `timestamp` — computation time

------------------------------------------------------------------------

## **Interpretation**

- **SHMI = 0** → No cover, no diversity, high disturbance, no organic
  inputs  
- **SHMI = 100** → Continuous cover, high diversity, no disturbance,
  frequent organic inputs  
- Pillar weights reflect national priorities in locked mode  
- Expert mode enables research flexibility

------------------------------------------------------------------------
