# Model-fitting
### Step by step

I've generated a synthetic dataset you can use to follow along with a similar format to one siteyear of my data. The columns are a field **block**, a **plot ID** code, the **C:N** ratio of the aboveground biomass at cover crop termination, the rate of **poultry litter** applied as kg PAN ha<sup>-1</sup>, and the **yield** in Mg ha<sup>-1</sup>. A note on style: throughout, I'll be mixing code and output to the console, but output will always be preceded and succeeded by `###`.

```r
library(readr)

demo_df <- read_csv("https://raw.githubusercontent.com/brianwdavis/liebig/master/demo_df.csv")

demo_df

###
# A tibble: 140 x 5
   block plotID        CN    pl     yield
   <chr>  <chr>     <dbl> <int>     <dbl>
 1     A    A20 10.056345     0 10.137356
 2     A    A44 11.205225    70 11.398971
 3     A    A32 12.892939   140 12.162282
 4     A    A43  9.824288   210  9.623026
 5     A    A17 10.912076   280  9.807880
 6     A    A40 16.991225     0 10.310636
 7     A    A26 17.997817    70 11.345654
 8     A    A27 16.370570   140 11.663027
 9     A    A31 20.448354   210 10.154312
10     A    A45 16.536603   280 12.871359
# ... with 130 more rows
###
```

Let's look at the data with a bit more rigor than this preview. First we'll load some useful packages.

```r
library(purrr)
library(ggplot2)
library(GGally)
library(dplyr)
library(tidyr)
library(nlme)
library(broom)
library(modelr)
library(mvnfast)


demo_df %>% map(summary)

```
```
###
$block
 A  B  C  D 
35 35 35 35 

$plotID
   Length     Class      Mode 
      140 character character 

$CN
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  9.256  18.500  39.300  54.830  83.510 170.400 

$pl
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
      0      70     140     140     210     280 

$yield
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  2.340   8.895  10.580  10.700  13.230  17.780 

$logcn
   Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
  2.225   2.918   3.671   3.668   4.425   5.138 
###
```
```r
ggpairs(demo_df %>% select(-plotID),
        lower = list(combo = "denstrip")) + 
  theme_bw()
```

![pairs plot for raw data](/images/demo_df.png)

We can see that the data are balanced among treatments, but that the C:N ratio is strongly skewed. It's probably a good idea to log-transform it.

```r
demo_df <- demo_df %>% 
  mutate(logcn = log(CN))
```

Now we need to get some starting values for the coefficients for a non-linear model. This is <a href = "https://stats.stackexchange.com/a/160575/108152">as much art as science</a>, but a good first guess is the coefficients from a regular linear model.

```r
lm(yield ~ pl + logcn, data = demo_df)

###
Call:
lm(formula = yield ~ pl + logcn, data = demo_df)

Coefficients:
(Intercept)           pl        logcn  
    12.0792       0.0209      -1.1749  
###
```

So I'll round these off and use them in `start = list(...)`.
Then we can try to fit a linear-plateau model across the two dimensions.

```r
demo_fit <- nlme(yield ~ beta0 + pmin(beta1*pl + beta2*logcn, beta3),
                 data   = demo_df,
                 fixed  = beta0 + beta1 + beta2 + beta3 ~ 1,
                 random = beta0 ~ 1 | block,
                 start  = list(beta0 = 10, beta1 = 0.01, 
                               beta2 = -1, beta3 = 10, 
                               fixed = rep(1, 4)))
###                               
Error in MEEM(object, conLin, control$niterEM) : 
  Singularity in backsolve at level 0, block 1  
###
```

This sort of error usually indicates that the algorithm is in a region of numerical instability. `nlme` operates best when all the variables have a similar range and variance, usually ~0 to ~1. It's an iterative process to guess what values might be needed for each variable. Since I've already done that process, you can just use these values. We also fit another `lm` to get new starting values.

```r
demo_df_rs <- demo_df %>% 
  mutate(pl    = 0.01 * pl,
         logcn = 0.01 * logcn,
         yield = 0.1  * yield)

lm(yield ~ pl + logcn, data = demo_df_rs)

###
Call:
lm(formula = yield ~ pl + logcn, data = demo_df_rs)

Coefficients:
(Intercept)           pl        logcn  
      1.208        0.209      -11.749  
###

demo_fit <- nlme(yield ~ beta0 + pmin(beta1*pl + beta2*logcn, beta3),
                 data   = demo_df_rs,
                 fixed  = beta0 + beta1 + beta2 + beta3 ~ 1,
                 random = beta0 ~ 1 | block,
                 start  = list(beta0 = 1, beta1 = 1, 
                               beta2 = -10, beta3 = 1, 
                               fixed = rep(1, 4)))
```

No error this time, so it converged. We still have to see if it converged to a reasonable global solution, or if the algorithm got stuck in a local minimum. If you're someone who likes progress bars, or at least some indication that work is happening, you can add `nlme(..., control = nlmeControl(msVerbose = ), verbose = T)`.

```r
summary(demo_fit)

###
Nonlinear mixed-effects model fit by maximum likelihood
  Model: yield ~ beta0 + pmin(beta1 * pl + beta2 * logcn, beta3) 
 Data: demo_df_rs 
        AIC       BIC   logLik
  -88.58407 -70.93422 50.29204

Random effects:
 Formula: beta0 ~ 1 | block
            beta0  Residual
StdDev: 0.1476349 0.1608993

Fixed effects: beta0 + beta1 + beta2 + beta3 ~ 1 
           Value Std.Error  DF   t-value p-value
beta0   1.547440 0.1273911 133 12.147153  0.0000
beta1   0.455642 0.0418668 133 10.883135  0.0000
beta2 -24.014303 2.7354226 133 -8.779010  0.0000
beta3  -0.289847 0.1047372 133 -2.767374  0.0065
 Correlation: 
      beta0  beta1  beta2 
beta1  0.140              
beta2 -0.777 -0.372       
beta3 -0.796 -0.170  0.945

Standardized Within-Group Residuals:
        Min          Q1         Med          Q3         Max 
-2.17064864 -0.72399404 -0.07072838  0.65030382  2.11700433 

Number of Observations: 140
Number of Groups: 4 
###


fixef(demo_fit)

###
      beta0       beta1       beta2       beta3 
  1.5474396   0.4556419 -24.0143035  -0.2898470 
###  
  
  
ranef(demo_fit)

###
        beta0
A -0.07468511
B  0.08039291
C -0.19294009
D  0.18723229
###
```

Next up: [model evaluation and selection](/model_selection.md).
