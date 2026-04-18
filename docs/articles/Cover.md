# SHMI Cover Sub‑index

Season‑Weighted Plant Presence

## **Overview**

The SHMI Cover sub‑index quantifies the proportion of days within a crop
rotation during which living plant cover is present, with explicit
weighting of the four meteorological seasons. The indicator reflects the
ecological principle that plant cover contributes differently to soil
health depending on the time of year (e.g., winter cover is
disproportionately valuable for erosion control). Cover is computed for
each management unit (MGT_combo) using daily crop‑presence data and
rotation start/end dates. The final score ranges from 0 to 100.

------------------------------------------------------------------------

### **1. Daily Inputs**

For each day d in a rotation window for management unit i, the input
data include:

``` math
\text{crop_present}_{i,d} \in \{0,1\}
```

``` math
\text{CD_name}_{i,d} \; \text{(used to force fallow → 0)}
```

``` math
\text{date}_{i,d}
```

``` math
\text{MGT_combo}_{i}
```

If multiple crops appear on the same day

``` math

\text{crop\_present}_{i,d} =
\begin{cases}
1 & \text{if any crop is present} \\
0 & \text{otherwise}
\end{cases}
```

Days where $`\text{CD_name} = \text{"fallow"}`$ are always set to 0.

------------------------------------------------------------------------

### **2. Assign Seasons**

Each day is assigned to a season based on calendar month:

``` math

\text{season}(d) =
\begin{cases}
\text{winter} & m \in \{12,1,2\} \\
\text{spring} & m \in \{3,4,5\} \\
\text{summer} & m \in \{6,7,8\} \\
\text{fall}   & m \in \{9,10,11\}
\end{cases}
```

------------------------------------------------------------------------

### **3. Seasonal Plant‑Days**

For each management unit $`i`$ and season $`s`$:

``` math

\text{plant_days}_{i,s} = \sum_{d \in s} \text{crop_present}_{i,d}
```

``` math

\text{days_possible}_{i,s} = \#\{ d \in s \}
```

This yields seasonal totals such as:

- $`\text{plant_days}_{i,\text{winter}}`$
- $`\text{days_possible}_{i,\text{winter}}`$

------------------------------------------------------------------------

### **4. Seasonal Proportions**

Seasonal cover proportions are bounded in $`[0,1]`$:

``` math

\text{prop}_{i,s} =
\begin{cases}
\dfrac{\text{plant_days}_{i,s}}{\text{days_possible}_{i,s}} & \text{if } \text{days_possible}_{i,s} > 0 \\
0 & \text{otherwise}
\end{cases}
```

This ensures rotations lacking days in a season (e.g., short rotations)
do not produce NaN values.

------------------------------------------------------------------------

### **5. Weight Normalization**

User‑supplied seasonal weights:

- $`w_{\text{winter}}`$
- $`w_{\text{spring}}`$
- $`w_{\text{summer}}`$
- $`w_{\text{fall}}`$

are normalized to sum to 1:

``` math

w_s^{*} = \frac{w_s}{\,w_{\text{winter}} + w_{\text{spring}} + w_{\text{summer}} + w_{\text{fall}}\,}
```

This guarantees interpretability and prevents scaling artifacts.

------------------------------------------------------------------------

### **6. Final Cover Score**

The SHMI Cover sub‑index for management unit $`i`$ is:

``` math

\text{Cover}_i = 100 \times \left(
w_{\text{winter}}^{*}\,\text{prop}_{i,\text{winter}} +
w_{\text{spring}}^{*}\,\text{prop}_{i,\text{spring}} +
w_{\text{summer}}^{*}\,\text{prop}_{i,\text{summer}} +
w_{\text{fall}}^{*}\,\text{prop}_{i,\text{fall}}
\right)
```

By construction:

``` math

0 \le \text{Cover}_i \le 100
```

------------------------------------------------------------------------

### **Interpretation**

- **0** → No plant cover in any season  
- **100** → Continuous cover in all seasons, weighted by seasonal
  importance  
- Seasonal weights allow tuning to local soil‑health priorities (e.g.,
  winter erosion control, summer evapotranspiration buffering)

------------------------------------------------------------------------

### **Output**

A data frame with one row per management unit:

| MGT_combo | Cover |
|:---------:|:-----:|
|     …     | 0–100 |

------------------------------------------------------------------------
