# SHMI Organic Inputs Sub‑index

Amendments + Animals (Weighted Annual Frequency)

## **Overview**

The SHMI Organic Inputs sub‑index quantifies the **frequency of
biological inputs**—organic amendments and animal presence—across the
rotation. Each rotation year is assigned a weighted organic‑input
presence based on user‑specified weights for amendments and animals. The
final score is scaled to **0–100**, where higher values indicate more
frequent biological inputs.

This sub‑index captures management practices that add organic matter,
stimulate microbial activity, and contribute to soil biological
functioning.

------------------------------------------------------------------------

## **1. Rotation‑Year Grid**

For each management unit $`i`$, a sequence of rotation years is
constructed:

``` math

\text{year} \in \{\text{rot_start_yr}_i, \ldots, \text{rot_end_yr}_i\}
```

This defines the evaluation window for organic inputs.

------------------------------------------------------------------------

## **2. Amendment Events**

Organic amendments are identified from the amendment table:

- Only rows with $`\text{SA_cat} = \text{"Organic"}`$ contribute.
- Amendment years are extracted as:

``` math

\text{year} = \text{year}(\text{SA_date})
```

Each amendment year is marked:

``` math

\text{amend_present}_{i,y} = 1
```

All other years receive 0.

------------------------------------------------------------------------

## **3. Animal Events**

Animal presence is identified from the animal table:

``` math

\text{year} = \text{year}(\text{AD_start_date})
```

Each year with animal presence is marked:

``` math

\text{ani_present}_{i,y} = 1
```

All other years receive 0.

------------------------------------------------------------------------

## **4. Weighted Organic‑Input Presence**

For each rotation year:

``` math

\text{weighted\_input}_{i,y}
= w_{\text{amend}} \cdot \text{amend_present}_{i,y}
+ w_{\text{animal}} \cdot \text{ani_present}_{i,y}
```

Default weights:

- $`w_{\text{amend}} = 1`$  
- $`w_{\text{animal}} = 1`$

Weights allow tuning based on local priorities or empirical
optimization.

------------------------------------------------------------------------

## **5. Rotation‑Average Input Frequency**

Let $`Y_i`$ be the number of rotation years for management unit $`i`$.  
Total weighted inputs across the rotation:

``` math

\text{total_weighted}_i = \sum_{y} \text{weighted_input}_{i,y}
```

Annualized frequency:

``` math

\text{events_per_year}_i
= \frac{\text{total_weighted}_i}{Y_i}
```

If $`Y_i = 0`$, the value defaults to 0.

------------------------------------------------------------------------

## **6. Scaling to 0–100**

If all management units have zero events:

``` math

\text{OrgInputs}_i = 0
```

Otherwise, values are rescaled to $`[0,100]`$ using a min–max
transformation:

``` math

\text{OrgInputs}_i = 100 \times
\frac{\text{events_per_year}_i - \min(\text{events_per_year})}
{\max(\text{events_per_year}) - \min(\text{events_per_year})}
```

This ensures comparability across systems with different event
frequencies.

------------------------------------------------------------------------

## **Interpretation**

- **0** → No organic amendments or animal presence across the rotation  
- **100** → Highest observed frequency of biological inputs  
- Weights allow emphasizing amendments, animals, or both  
- Captures management intensity related to organic matter and biological
  activity

------------------------------------------------------------------------

## **Output**

A data frame with one row per management unit:

| MGT_combo | OrgInputs |
|:---------:|:---------:|
|     …     |   0–100   |

------------------------------------------------------------------------
