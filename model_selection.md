# Model selection and evaluation

## Compare with competing models

In addition to [the model we just fit](/model_fitting.md), it's a good idea to test some other models and see how they perform. One particularly useful model is the null (with the same random effects, but intercept only):

```r
demo_fit_null <- 
  lme(yield ~ 1,
      data   = demo_df_rs,
      random = ~ 1 | block,
      method = "ML")
                     
anova(demo_fit, demo_fit_null)
```
```
###
              Model df       AIC       BIC    logLik   Test  L.Ratio p-value
demo_fit          1  6 -88.58407 -70.93422  50.29204                        
demo_fit_null     2  3  85.56322  94.38815 -39.78161 1 vs 2 180.1473  <.0001
###
```

We can see that the `demo_fit` model has a significantly (p<0.0001) higher likelihood, which is supported by the lower AIC and BIC values. So we can infer that our treatments are having an effect on the grain yield, as opposed to an intercept-only model. Next we might test whether there's an interaction between **PL** and **CN**. Just like before, we'll first fit a regular `lm` to get starting values.

```r
lm(yield ~ pl * logcn, data = demo_df_rs)

###
Call:
lm(formula = yield ~ pl * logcn, data = demo_df_rs)

Coefficients:
(Intercept)           pl        logcn     pl:logcn  
     1.7469      -0.1803     -26.4672      10.6549 
###


demo_fit_x <- 
  nlme(yield ~ beta0 + pmin(beta1*pl + beta2*logcn + beta4*pl*logcn, beta3),
       data   = demo_df_rs,
       fixed  = beta0 + beta1 + beta2 + beta3 + beta4 ~ 1,
       random = beta0 ~ 1 | block,
       start  = list(beta0 = 1, 
                     beta1 = 1, 
                     beta2 = -10, 
                     beta3 = 1, 
                     beta4 = 10,
                     fixed = rep(1, 5)))


anova(demo_fit, demo_fit_x)
```
```
###
           Model df       AIC       BIC   logLik   Test  L.Ratio p-value
demo_fit       1  6 -88.58407 -70.93422 50.29204                        
demo_fit_x     2  7 -90.03916 -69.44766 52.01958 1 vs 2 3.455089  0.0631
###
```

The AIC is lower for the interaction model and the BIC is lower for the additive model, but the likelihood ratio test says there's no significant difference between them. One might consider the more parsimonious model to be better (for some definition of better). I'll do that for the following analyses and leave it as an exercise to the reader to investigate what this model looks like with an interaction.

## Evaluate model fit

Now we might want to make sure that this is a reasonable model that we've chosen. We can check the properties of the residuals, just like with a regular `lm`. First we `broom::augment` the model to generate the predictions using all effects and fixed effects only as well as residuals. Then we create an additional column of standardized residuals by scaling them to a variance of 1.

```r
demo_df_aug <- 
  augment(demo_fit, demo_df_rs) %>% 
  mutate(.std.resid = .resid / sd(.resid))

ggplot(demo_df_aug, 
       aes(.fixed, .resid)) + 
  geom_point() + 
  stat_smooth() +
  theme_bw() + 
  labs(x = "Predicted values, fixed effects only",
       y = "Residuals")

ggplot(demo_df_aug, 
       aes(sample = .std.resid)) + 
  geom_abline() + 
  stat_qq() + 
  theme_bw()
```

|![](/images/resid.png) |![](/images/qq.png)|
|-----------------------|-------------------|

Then we might want to summarize the model by some measure of goodness-of-fit beyond the AIC/BIC generated above. The concept of R<sup>2</sup> for a non-linear model isn't exactly clear, but there are some analogues in use.

```r
# RMSE
sqrt(var(demo_df_aug$.resid))

###
0.1592303
###
# Recall that our response was scaled
# True RMSE is 1.59 Mg/ha

# Omega^2: Xu
1 - var(demo_df_aug$.resid) / var(demo_df_aug$yield)

###
0.7848197
###
# This can be somewhat interpreted as "variance explained" like R^2.

# Pseudo-R^2: Cox-Snell
demo_ll <- as.numeric(logLik(demo_fit))
demo_ll0 <- as.numeric(logLik(demo_fit_null))

1 - exp(2*(demo_ll0 - demo_ll)/nobs(demo_fit))

###
0.7238377
###
# This is the goodness-of-fit of our model relative to the null model.
# Recall that our null model had the same random effects, so this measures
#   just the fit due to the fixed effects, PL and CN.

```
There are other such measures of goodness-of-fit, but taken together, RMSE=1.59 Mg ha<sup>-1</sup>, Ω<sup>2</sup>=0.78, and *p*-R<sup>2</sup>=0.72 give you a reasonable idea of how the model performs.

## Model summary

To print our model as a table of coefficients, we need to derive a few extra parameters of interest from the model. Recall:

![](/images/models%20cropped%20with%20hats%20and%20left%20aligned.png)

We want to define the frontier at the minimum rate of PL to achieve maximum yield. So we set the operands of the `min` function to be equal, since that's the changepoint. By rearranging terms, we get the lower pair of equations. In addition, we can derive **Yield<sub>max</sub>** = β<sub>0</sub>+β<sub>3</sub>. However, the coefficients from our `demo_fit` aren't *true*, they're just estimates. We need to account for both the uncertainty in each one, as well as the covariance between them, when we do any arithmetic on them.

> Note: <a href = "https://www.wolframalpha.com/input/?i=b3+%3D+b1*y+%2B+b2*x+%2B+b4*x*y,+solve+for+y">To generate the frontier for the interaction, it's helpful to have computers do the algebra for you</a>.

Monte Carlo simulations are a good way to do this. We can approximate large numbers of samples of coefficient estimates as coming from a joint-normal distribution, with the means and covariance matrix given by R.

```
fixef(demo_fit)

###
      beta0       beta1       beta2       beta3 
  1.5474396   0.4556419 -24.0143035  -0.2898470 
###

vcov(demo_fit)

###
             beta0        beta1       beta2        beta3
beta0  0.015764828  0.000724643 -0.26287353 -0.010315810
beta1  0.000724643  0.001702747 -0.04134221 -0.000724643
beta2 -0.262873533 -0.041342213  7.26874997  0.262873538
beta3 -0.010315810 -0.000724643  0.26287354  0.010656450
###
```
```r
rmvn(1000, fixef(demo_fit), vcov(demo_fit), kpnames = T) %>% 
  as_data_frame()
```
```
###  
# A tibble: 1,000 x 4
      beta0     beta1     beta2      beta3
      <dbl>     <dbl>     <dbl>      <dbl>
 1 1.384270 0.4447768 -23.36637 -0.2559584
 2 1.623660 0.4344525 -26.10855 -0.4140665
 3 1.537214 0.4851915 -24.30450 -0.2957845
 4 1.602308 0.3843402 -24.86724 -0.3647044
 5 1.746162 0.4089032 -26.46807 -0.4207473
 6 1.411716 0.4616296 -23.42540 -0.2681241
 7 1.445341 0.4576628 -24.39756 -0.2893648
 8 1.587089 0.4367224 -25.64430 -0.3428215
 9 1.387170 0.4262968 -20.43595 -0.1381052
10 1.589759 0.4519635 -22.68225 -0.2481625
# ... with 990 more rows  
###
```

`mvnfast::rmvn` is doing the population sampling for us. However, recall that we had scaled our variables to fit the model, so now we need to unscale them by the appropriate factors. (If anyone can think of a good programmatic way to do this, do not hesitate to let me know.)

Then we can generate our new parameters, plot them, and summarize them in a way suitable for a table.

```r
demo_mc_coefs <- 
rmvn(1000, fixef(demo_fit), vcov(demo_fit), kpnames = T) %>% 
  as_data_frame() %>% 
  mutate(beta0 = beta0 * 1/0.1,
         beta1 = beta1 * 0.01/0.1,
         beta2 = beta2 * 0.01/0.1,
         beta3 = beta3 * 1/0.1) %>% 
  mutate(gamma0 = beta3/beta1,
         gamma1 = -beta2/beta1,
         Ymax   = beta0 + beta3)
         
light <-
  function (data, mapping, ...) {
  
    ggplot(data = data, 
           mapping = mapping) + 
      geom_point(alpha = 0.1, ...)
      
  }

ggpairs(demo_mc_coefs,
        lower = list(continuous = light)) + 
  theme_bw() + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))
```
![](/images/mc_coefs.png)

### Model table

```r
demo_mc_coefs %>% 
  gather() %>% 
  group_by(key) %>% 
  summarise(estimate = mean(value), 
            se = sd(value)) %>% 
  mutate_if(is.numeric, 
            funs(signif(., 3)))
  
###
# A tibble: 7 x 3
   param estimate      se
   <chr>    <dbl>   <dbl>
1  beta0  15.5000  1.2800
2  beta1   0.0457  0.0041
3  beta2  -2.4000  0.2700
4  beta3  -2.8800  1.0500
5 gamma0 -63.2000 23.0000
6 gamma1  52.7000  6.2200
7   Ymax  12.6000  0.7850
###
```



Next up: [model visualization](/model_viz.md).
