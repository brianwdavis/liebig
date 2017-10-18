# Visualizing the model

## Generate a grid

The first step to plotting complex models is to generate a grid of all possible independent variable values and the corresponding model predictions. The `modelr` package can help with that. Here we use the ranges of **pl** and **logcn** in the original data, but create sequences along those ranges of 100x100 evenly spaced points.

```r
demo_grid <- 
  data_grid(demo_df_rs %>% ungroup, 
            pl = seq_range(pl, 100), 
            logcn = seq_range(logcn, 100))
       
demo_grid

###
# A tibble: 10,000 x 2
      pl      logcn
   <dbl>      <dbl>
 1     0 0.02225297
 2     0 0.02254721
 3     0 0.02284145
 4     0 0.02313569
 5     0 0.02342993
 6     0 0.02372417
 7     0 0.02401841
 8     0 0.02431264
 9     0 0.02460688
10     0 0.02490112
# ... with 9,990 more rows
###
```

Now we can add the predictions and rescale the values to their original scale. Also we add a factor to identify the individual levels of the **CN** variable, for convenience with plotting. 

The `level = 0` argument of `predict` indicates to use the population-level predictions (fixed effects only). If you want to use the fitted values, accounting for the random effects, you can use `level = 1`, but you also need to add `data_grid(..., block, ...)` above. This is helpful if your random effects include siteyears that you want to plot separately, as I did on the poster. However, it will cause problems with plotting everything we've done so far in a single panel, so we're using fixed effects only.

```
demo_grid_aug <- 
  demo_grid %>% 
  mutate(.fixed  = 10 * predict(demo_fit, newdata = ., level = 0),
         CN      = exp(100*logcn),
         pl      = 100*pl,
         CNid    = factor(CN, label = "cn"))
         
demo_grid_aug

###
# A tibble: 10,000 x 5
      pl      logcn    .fixed        CN   CNid
   <dbl>      <dbl>     <dbl>     <dbl> <fctr>
 1     0 0.02225297 10.130499  9.256234    cn1
 2     0 0.02254721 10.059840  9.532635    cn2
 3     0 0.02284145  9.989180  9.817289    cn3
 4     0 0.02313569  9.918521 10.110444    cn4
 5     0 0.02342993  9.847862 10.412352    cn5
 6     0 0.02372417  9.777202 10.723276    cn6
 7     0 0.02401841  9.706543 11.043484    cn7
 8     0 0.02431264  9.635883 11.373254    cn8
 9     0 0.02460688  9.565224 11.712871    cn9
10     0 0.02490112  9.494565 12.062629   cn10
# ... with 9,990 more rows
###
```

## "Side-on" view of the response curve

```
PL_lab <- expression("PL rate, kg PAN ha"^-1)
GY_lab <- expression("Grain yield, Mg ha"^-1)
CN_lab <- "C:N ratio, log-scaled"


fig_side <-
ggplot(demo_grid_aug, aes(x = pl, y = .fixed)) + 
  geom_line(aes(group = CNid, color = CN)) + 
  theme_classic() + 
  theme(legend.position = "top") +
  labs(x = PL_lab, y = GY_lab, color = CN_lab) +  
  scale_color_viridis(option = "C", 
                      trans = "log10", 
                      end = 0.9,
                      breaks = 10 * 2^(0:4))

fig_side
```

![](/images/demo_alongX.png)

This figure shows the intuitive shape of a linear-plateau curve along the N fertilization gradient (**PL**), with each possible level of **CN** represented as a parallel line. Each line is shifted to the right as **CN** ratio increases, and left as **CN** ratio decreases. Each line eventually reaches the plateau, but it's difficult to describe quantitatively how far along that envelope of responses a given cover crop quality is.

We might want to add in our original data to give some context to the model fits. To do that, we just add another layer of points, giving a `data =` argument to point back to the original set. The only difference is that we want to plot each point at the actual **yield** value, not the model prediction, so we have to update the `y` aesthetic.

```r
fig_side +
  geom_point(data = demo_df, 
             aes(y = yield), 
             alpha = 0.5)
```

![](/images/demo_alongX_data.png)

## "Top-down" view of the frontier

```
fig_top <-
ggplot(demo_grid_aug, aes(x = CN, y = pl)) + 
  stat_contour(aes(z = .fixed, color = ..level..)) + 
  geom_point(data = demo_df, aes(color = yield)) +
  theme_classic() + 
  theme(legend.position = "top") +
  labs(x = CN_lab, y = PL_lab, color = GY_lab) +
  scale_x_log10(breaks = 10 * 2^(0:4)) +  
  scale_color_viridis() 
  
fig_top
```

Looking "down" at the data from "above", we can see that there's a full response surface represented, but there is no effect of treatment in the upper-left half of the space. This is the plateau region in a traditional linear-plateau curve. `stat_contour` generates a series of isoquants at round numbers of predicted yield (4, 5, 6, etc.), which are the diagonal lines, but it doesn't necessarily mark the frontier, which is the equivalent of the changepoint in a traditional linear-plateau curve. We'll have to calculate that below.

Again for context, we can add a layer of points for the raw data:

```r
fig_top <-
  fig_top +
  geom_point(data = demo_df, 
             aes(color = yield))

fig_top
```

![](/images/demo_alongZ_data.png)

### Finding the frontier

To calculate the position (and uncertainty) for the frontier, we have to use our previously simulated coefficients.

```
demo_mc_coefs

###
# A tibble: 1,000 x 7
      beta0      beta1     beta2      beta3    gamma0   gamma1     Ymax
      <dbl>      <dbl>     <dbl>      <dbl>     <dbl>    <dbl>    <dbl>
 1 16.05794 0.04378062 -2.541802 -3.6357577 -83.04491 58.05769 12.42218
 2 15.61554 0.04580369 -2.209846 -2.1882875 -47.77535 48.24602 13.42725
 3 13.89307 0.04736644 -2.120063 -1.6581159 -35.00613 44.75876 12.23495
 4 13.32746 0.04277710 -2.069687 -2.0840939 -48.71985 48.38306 11.24337
 5 16.98919 0.04694758 -2.812116 -4.3551419 -92.76606 59.89908 12.63405
 6 16.40717 0.04619183 -2.594565 -3.8734240 -83.85518 56.16935 12.53375
 7 13.49385 0.05449645 -2.433052 -2.5298679 -46.42262 44.64606 10.96399
 8 15.77818 0.04188125 -2.463029 -3.4662955 -82.76485 58.80983 12.31189
 9 13.25988 0.04868941 -1.792649 -0.2212544  -4.54420 36.81806 13.03862
10 15.18405 0.04464636 -2.404750 -2.8883076 -64.69302 53.86218 12.29575
# ... with 990 more rows
###
```

For each row (individual simulation), we want to calculate the position of the frontier across the entire range of **CN**. For this particular use, our `demo_grid_aug` is overkill, so we'll make a simpler one:

```r
demo_grid_logcn <- 
  data_grid(demo_df_rs %>% ungroup, 
            logcn = 100*seq_range(logcn, 50))
  
  
demo_grid_logcn 

###
# A tibble: 50 x 1
      logcn
      <dbl>
 1 2.225297
 2 2.284746
 3 2.344194
 4 2.403642
 5 2.463090
 6 2.522538
 7 2.581987
 8 2.641435
 9 2.700883
10 2.760331
# ... with 40 more rows
###
```

Now we'll embed this entire dataframe over and over into each row of our simulated coefficients as a list-column.

```
demo_mc_coefs %>% 
  select(gamma0, gamma1) %>% 
  mutate(grid = list(demo_grid_logcn))
  
###
# A tibble: 1,000 x 3
      gamma0   gamma1              grid
       <dbl>    <dbl>            <list>
 1 -83.04491 58.05769 <tibble [50 x 1]>
 2 -47.77535 48.24602 <tibble [50 x 1]>
 3 -35.00613 44.75876 <tibble [50 x 1]>
 4 -48.71985 48.38306 <tibble [50 x 1]>
 5 -92.76606 59.89908 <tibble [50 x 1]>
 6 -83.85518 56.16935 <tibble [50 x 1]>
 7 -46.42262 44.64606 <tibble [50 x 1]>
 8 -82.76485 58.80983 <tibble [50 x 1]>
 9  -4.54420 36.81806 <tibble [50 x 1]>
10 -64.69302 53.86218 <tibble [50 x 1]>
# ... with 990 more rows
###
```

These steps can be computationally challenging. Depending on the size of your grid and the size of your coefficient simulation, you may start to get unwieldy numbers of observations quite quickly. I recommend working with a subset of each to figure out how long the operation might take. There are ways to parallelize `dplyr` functions that are beyond the scope of this tutorial. Luckily with this small dataset, the computation is very fast.

We expand out each of the nested dataframes and calculate the **PL** saturation point using the γ coefficients.

```
demo_mc_coefs %>% 
  select(gamma0, gamma1) %>% 
  mutate(grid = list(demo_grid_logcn)) %>% 
  unnest() %>% 
  mutate(pl = gamma0 + gamma1*logcn)
  
###
# A tibble: 50,000 x 4
      gamma0   gamma1    logcn       pl
       <dbl>    <dbl>    <dbl>    <dbl>
 1 -83.04491 58.05769 2.225297 46.15071
 2 -83.04491 58.05769 2.284746 49.60213
 3 -83.04491 58.05769 2.344194 53.05356
 4 -83.04491 58.05769 2.403642 56.50499
 5 -83.04491 58.05769 2.463090 59.95642
 6 -83.04491 58.05769 2.522538 63.40784
 7 -83.04491 58.05769 2.581987 66.85927
 8 -83.04491 58.05769 2.641435 70.31070
 9 -83.04491 58.05769 2.700883 73.76213
10 -83.04491 58.05769 2.760331 77.21355
# ... with 49,990 more rows
###
```

Now we `group_by` each possible level of `logcn` in our grid and find the mean and error associated with all the possible levels of PL saturation points. Finally, we exponentiate the `logcn` column back to a **CN** value for our convenience.

```
demo_frontier <- 
demo_mc_coefs %>% 
  select(gamma0, gamma1) %>% 
  mutate(grid = list(demo_grid_logcn)) %>% 
  unnest() %>% 
  mutate(pl = gamma0 + gamma1*logcn) %>% 
  group_by(logcn) %>% 
  summarise(pl_se  = sd(pl),
            pl = mean(pl)) %>% 
  mutate(CN = exp(logcn))


demo_frontier

###
# A tibble: 50 x 4
      logcn    pl_se       pl        CN
      <dbl>    <dbl>    <dbl>     <dbl>
 1 2.225297 12.03033 54.13358  9.256234
 2 2.284746 11.82072 57.26928  9.823186
 3 2.344194 11.61912 60.40499 10.424865
 4 2.403642 11.42592 63.54070 11.063396
 5 2.463090 11.24158 66.67640 11.741038
 6 2.522538 11.06654 69.81211 12.460187
 7 2.581987 10.90123 72.94782 13.223383
 8 2.641435 10.74612 76.08352 14.033327
 9 2.700883 10.60164 79.21923 14.892879
10 2.760331 10.46824 82.35494 15.805081
# ... with 40 more rows
###
```

We can plot this data on top of our last figure. Note that the band is *prediction* intervals, not *confidence* intervals, since we are plotting the region where 95% of the data are.

```
fig_top +
  geom_ribbon(data = demo_frontier, 
              aes(ymin = pl - 1.96*pl_se,
                  ymax = pl + 1.96*pl_se),
              fill = "grey75", alpha = 0.5) +
  geom_line(data = demo_frontier, size = 1.5)
```

![](/images/demo_alongZ_frontier.png)

While this figure is more cognitively-tasking to understand and interpret, it emphasizes the frontier we derived as its primary focus. This is the most functionally interesting part of our model: we can predict what minimum level of fertilization should be done in-season to achieve maximum yield of our cash crop, given the quality of the cover crop that grew in the winter prior.

If you've made it this far, please go check out what this looks like in 3d: https://brianwdavis.shinyapps.io/liebig/
