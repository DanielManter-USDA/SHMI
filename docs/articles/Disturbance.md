# Inverse Disturbance Subindex

Mechanistic Inverse Disturbance (Mixing‑Efficiency × Depth Model)

## **Overview**

The SHMI Inverse Disturbance subindex quantifies **mechanical soil
disturbance** using a mechanistic soil‑mixing model based on **mixing
efficiency** and **tillage depth**. Disturbance is computed at the
**annual** scale and then averaged across the rotation. The final score
is expressed as **inverse disturbance**, scaled to **0–100**, where
higher values indicate less mechanical disturbance.

This formulation captures both the *intensity* and *cumulative
penetration* of tillage operations, reflecting how repeated passes
reduce the effective depth of subsequent disturbance.

------------------------------------------------------------------------

## **1. Inputs**

Daily disturbance data for each management unit $`i`$ include:

- $`\text{SD_mixeff}_{i,d}`$ — mixing efficiency (0–1)  
- $`\text{SD_depth_cm}_{i,d}`$ — tillage depth in cm (capped at 30)  
- $`\text{date}_{i,d}`$ — calendar date  
- $`\text{MGT_combo}_i`$

Rotation bounds provide:

- $`\text{rot_start}_i`$  
- $`\text{rot_end}_i`$

Depth is normalized as:

``` math

\text{SD_depth_cm} = \min(\text{SD_depth_cm}, 30)
```

------------------------------------------------------------------------

## **2. Annual Ordering of Disturbance Events**

Within each year, disturbance events are ordered by:

1.  Management unit  
2.  Year  
3.  Depth  
4.  Mixing efficiency

This ensures deeper, more aggressive operations are applied first in the
cumulative‑mixing model.

------------------------------------------------------------------------

## **3. Mechanical Energy and Cumulative Penetration**

For each disturbance event $`i`$:

### **Mechanical energy contribution**

``` math

ME_i = \text{SD_mixeff}_i \times \text{SD_depth_cm}_i
```

### **Cumulative mechanical energy**

``` math

\text{cumME}_i = \sum_{j < i} ME_j
```

------------------------------------------------------------------------

## **4. Profile Penetration ( $`T_t`$ )**

The effective penetration of each disturbance event is:

``` math

T_{t,i} = \text{SD_mixeff}_i \times \max\left(0,\; \text{SD_depth_cm}_i - \text{cumME}_i \right)
```

Normalized by the 30‑cm reference depth:

``` math

T_{t,i}^{\text{norm}} = \frac{T_{t,i}}{30}
```

------------------------------------------------------------------------

## **5. Annual Disturbance**

Annual disturbance is the sum of normalized penetrations:

``` math

T_t^{\text{annual}} = \sum_i T_{t,i}^{\text{norm}}
```

------------------------------------------------------------------------

## **6. Inverse Disturbance**

Annual inverse disturbance is:

``` math

T_t^{\text{inv}} = 1 - T_t^{\text{annual}}
```

Values below 0 or above 1 are not expected under the capped model.

------------------------------------------------------------------------

## **7. Rotation‑Scale Disturbance**

Annual inverse disturbance is averaged across all rotation years:

``` math

\text{InvDist}_i = 100 \times \text{mean}\left(T_{t,y}^{\text{inv}}\right)
```

If a management unit has **no disturbance events**, then:

``` math

\text{InvDist}_i = 100
```

------------------------------------------------------------------------

## **Interpretation**

- **100** → No mechanical disturbance  
- **0** → Maximum possible disturbance (deep, repeated, high‑efficiency
  tillage)  
- The metric captures both **depth** and **cumulative mixing**,
  penalizing repeated passes  
- The 30‑cm cap ensures comparability across systems

------------------------------------------------------------------------

## **Output**

A data frame with one row per management unit:

| MGT_combo | InvDist |
|-----------|---------|
| …         | 0–100   |

------------------------------------------------------------------------
