# NAPESHM: development vs installed version

    Code
      cat("Units compared:", nrow(cmp), "\n")
    Output
      Units compared: 508 
    Code
      cat("Units with |change in SHMI| >", tol, ":", nrow(moved), "\n\n")
    Output
      Units with |change in SHMI| > 0.01 : 35 
      
    Code
      print(by_pillar, row.names = FALSE)
    Output
          pillar units_moved max_up max_down
            SHMI          35   0.44   -26.66
           Cover          27   0.00   -59.50
       Diversity           8   4.89     0.00
         InvDist           0   0.00     0.00
        OrgInput           0   0.00     0.00
    Code
      cat("\nUnits whose SHMI moved (largest first):\n")
    Output
      
      Units whose SHMI moved (largest first):
    Code
      if (nrow(moved) == 0) cat("none\n") else print(moved, row.names = FALSE)
    Output
                MGT_combo SHMI_installed SHMI_dev d_SHMI d_Cover d_Diversity
       NAPESHM_USCA01_173          55.41    28.75 -26.66  -59.50        0.00
       NAPESHM_USFL02_230          62.87    42.36 -20.51  -45.77        0.00
       NAPESHM_USFL02_231          62.08    43.43 -18.65  -41.63        0.00
       NAPESHM_USNC03_365          57.16    40.30 -16.85  -37.61        0.00
       NAPESHM_USOK01_430          67.98    51.83 -16.15  -36.03        0.00
       NAPESHM_USCA03_178          66.03    52.83 -13.20  -29.45        0.00
       NAPESHM_USCA02_174          72.03    58.90 -13.13  -29.31        0.00
       NAPESHM_USCA02_175          50.97    37.84 -13.13  -29.31        0.00
       NAPESHM_USSC02_459          64.87    54.09 -10.78  -24.06        0.00
       NAPESHM_USSC02_460          60.23    49.44 -10.78  -24.06        0.00
        NAPESHM_MXPU01_76          74.11    64.58  -9.53  -21.27        0.00
       NAPESHM_USTX02_469          64.35    55.77  -8.57  -19.13        0.00
       NAPESHM_USTX02_470          60.74    52.17  -8.57  -19.13        0.00
       NAPESHM_USFL01_229          64.27    57.53  -6.74  -15.03        0.00
       NAPESHM_USNC03_361          61.71    56.10  -5.61  -12.52        0.00
       NAPESHM_USAL01_137          59.40    54.81  -4.59  -10.24        0.00
       NAPESHM_USAL01_138          62.43    57.85  -4.59  -10.24        0.00
       NAPESHM_USAL01_139          80.46    75.87  -4.59  -10.24        0.00
       NAPESHM_USAL01_140          83.50    78.91  -4.59  -10.24        0.00
       NAPESHM_USFL01_228          67.06    62.96  -4.10   -9.16        0.00
       NAPESHM_USOK01_432          67.48    63.43  -4.05   -9.03        0.00
       NAPESHM_USAL04_163          62.46    59.00  -3.46   -7.72        0.00
       NAPESHM_USAL04_161          74.84    73.25  -1.59   -3.55        0.00
       NAPESHM_USAL04_162          64.06    62.47  -1.59   -3.55        0.00
       NAPESHM_USAL03_157          62.93    61.56  -1.36   -3.04        0.00
       NAPESHM_USSD02_463          67.46    66.49  -0.98   -2.18        0.00
       NAPESHM_USPA01_446          66.62    67.07   0.44    0.00        4.89
       NAPESHM_USPA01_452          64.67    65.11   0.44    0.00        4.89
         NAPESHM_MXAG01_1          48.58    48.89   0.31    0.00        3.41
         NAPESHM_MXAG01_2          48.58    48.89   0.31    0.00        3.41
         NAPESHM_MXAG01_3          51.84    52.15   0.31    0.00        3.41
         NAPESHM_MXAG01_4          38.11    38.41   0.31    0.00        3.41
         NAPESHM_MXAG01_5          51.84    52.15   0.31    0.00        3.41
       NAPESHM_USSD02_461          66.11    65.89  -0.21   -0.48        0.00
       NAPESHM_USGA01_232          41.39    41.50   0.11    0.00        1.17
       d_InvDist d_OrgInput
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0
               0          0

