# Model selection and evaluation

In addition to [the model we just fit](/model_fitting.md), it's a good idea to test some other models and see how they perform. One particularly useful model is the null (with the same random effects, but intercept only):

```r
demo_fit_null <- lme(yield ~ 1,
                     data   = demo_df_rs,
                     random = ~ 1 | block,
                     method = "ML")
                     
anova(demo_fit, demo_fit_null)

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


demo_fit_x <- nlme(yield ~ beta0 + pmin(beta1*pl + beta2*logcn + beta4*pl*logcn, beta3),
                   data   = demo_df_rs,
                   fixed  = beta0 + beta1 + beta2 + beta3 + beta4 ~ 1,
                   random = beta0 ~ 1 | block,
                   start  = list(beta0 = 1, beta1 = 1, 
                                 beta2 = -10, beta3 = 1, 
                                 beta4 = 10,
                                 fixed = rep(1, 5)))


anova(demo_fit, demo_fit_x)

###
           Model df       AIC       BIC   logLik   Test  L.Ratio p-value
demo_fit       1  6 -88.58407 -70.93422 50.29204                        
demo_fit_x     2  7 -90.03916 -69.44766 52.01958 1 vs 2 3.455089  0.0631
###
```

The AIC is lower for the interaction model and the BIC is lower for the additive model, but the likelihood ratio test says there's no significant difference between them. One might consider the more parsimonious model to be better (for some definition of better). I'll do that for the following analyses and leave it as an exercise to the reader to investigate what this model looks like with an interaction.

To print our model as a table of coefficients, we need to derive a few extra parameters of interest from the model. Recall:

![](/images/models%20cropped%20with%20hats%20and%20left%20aligned.png)

We want to define the frontier at the minimum rate of PL to achieve maximum yield. So we set the operands of the `min` function to be equal, since that's the changepoint. By rearranging terms, we get the lower pair of equations. In addition, we can derive **Yield<sub>max</sub>** = β<sub>0</sub>+β<sub>3</sub>. However, the coefficients from our `demo_fit` aren't *true*, they're just estimates. We need to account for both the uncertainty in each one, as well as the covariance between them, when we do any arithmetic on them.

> Note: <a href = "https://www.wolframalpha.com/input/?i=b3+%3D+b1*y+%2B+b2*x+%2B+b4*x*y,+solve+for+y">To generate the frontier for the interaction, it's helpful to have computers do the algebra for you</a>.

Monte Carlo simulations are a good way to do this. We can approximate large numbers of samples of coefficient estimates as coming from a joint-normal distribution, with the means and covariance matrix given by R.

```r
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


rmvn(1000, fixef(demo_fit), vcov(demo_fit), kpnames = T) %>% 
  as_data_frame()
  
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

`rmvn` is doing the population sampling for us. However, recall that we had scaled our variables to fit the model, so now we need to unscale them by the appropriate factors. (If anyone can think of a good programmatic way to do this, do not hesitate to let me know.)

Then we can generate our new parameters, summarize them, and plot them.

```r
demo_mc_coefs <- 
rmvn(1000, fixef(demo_fit), vcov(demo_fit), kpnames = T) %>% 
  as_data_frame() %>% 
  mutate(beta0  = beta0 *    1 / 0.1,
         beta1  = beta1 * 0.01 / 0.1,
         beta2  = beta2 * 0.01 / 0.1,
         beta3  = beta3 *    1 / 0.1) %>% 
  mutate(gamma0 = beta3/beta1,
         gamma1 = -beta2/beta1,
         Ymax = beta0 + beta3)
         

demo_mc_coefs %>% 
  gather(key = param, value = value) %>% 
  group_by(param) %>% 
  summarise(estimate = mean(value), se = sd(value))
  
###
# A tibble: 7 x 3
   param     estimate           se
   <chr>        <dbl>        <dbl>
1  beta0  15.47076119  1.278354958
2  beta1   0.04571399  0.004102627
3  beta2  -2.40019360  0.269551663
4  beta3  -2.88273130  1.048210067
5 gamma0 -63.24381856 22.992277501
6 gamma1  52.74683771  6.221282735
7   Ymax  12.58802989  0.785173467
###


ggpairs(demo_mc_coefs) + 
  theme_bw() + 
  theme(axis.text.x = element_text(angle = 90, hjust = 1, vjust = 0.5))
```

![](/images/mc_coefs.png)

Next up: [model visualization](/model_viz.md).
