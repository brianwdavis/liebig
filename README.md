## Linear-plateau response surfaces

| A 3d surface demonstration: |  
|:-------------------------------------|
| https://brianwdavis.shinyapps.io/liebig/| 
| **The original poster:** |
| [Davis et al., 2017](/Davis_et_al_2017_Liebig_in_2_Dimensions.pdf) |

> *Click on "View all of README.md" if this page isn't fully visible on your device.*

***

### Annotated code for von Liebig model-fitting

* Model fitting: [model_fitting.md](/model_fitting.md)
* Model selection: [model_selection.md](/model_selection.md)
* Model visualization: [model_viz.md](/model_viz.md)

* Bayesian (`brms`) comparison: coming soon
* Alternative functional model candidates: coming soon
* References: coming soon


Throughout, if you have any questions or corrections, don't hesitate to [file an issue](https://github.com/brianwdavis/liebig/issues) or email me at brianwdavis@gmail.com

***

Motivating model:

![Eq1: Yield = beta0 + min(beta1*PL+beta2*logCN), beta3)](/images/models%20cropped%20with%20hats%20and%20left%20aligned.png "\begin{equation}
  \begin{aligned}
    &\text{Yield} &=& &\beta_0& + \min\begin{cases} \beta_1\times \text{PL} + \beta_2\times \ln(\text{C:N ratio}) \\  \beta_3 \end{cases} + \varepsilon_N
  \end{aligned}
 \end{equation}
\begin{equation}
    \begin{aligned}
    &\text{PL}_{sat} &=& &\frac{\hat\beta_3}{\hat\beta_1}& &+& &\frac{-\hat\beta_2}{\hat\beta_1}& &\times& &\ln(\text{C:N ratio})& \\
    &\text{PL}_{sat} &=& &\hat\gamma_0& &+& &\hat\gamma_1& &\times& &\ln(\text{C:N ratio})&
  \end{aligned}
\end{equation}
")

The lower pair of equations is derived from the model by finding the point where the two operands of the `min` function meet. Rearranging algebraically for PL finds the PL "saturation point", as defined by a line running through the space of C:N ratio.

The purpose of this repository is to provide a bit more perspective (no pun intended) on visualizing two-way models. First, we might consider the classic von Liebig yield response curve, a linear plateau. When you imagine it, you see a line sloping up as you increase fertilizer N (here poultry litter), hitting a changepoint, and then flattening out. The most intuitive representation then might be such a figure, but with a series of lines for each level of your second variable (cover crop quality in this analysis). Given the terms in our model, here's how that might look:

![Along x-axis, annotated](/images/alongXanno.png)

The net result for all our site years would look like this:

![Along x-axis with data](/images/alongX.png)


Here you can see the classic shape of the linear-plateau relationship along the PL axis, but enveloping a region of varying C:N ratios. The lines that are higher in yield for a given rate of PL are more bluish-purple, meaning a low C:N ratio residue dominated by hairy vetch. The lines that are lower in yield for a given rate of PL are more orangey-yellow, meaning a high C:N ratio residue dominated by cereal rye.

This figure's strength is understanding and interpreting qualitatively. However, you can't really tell what the relationship between the independent variables is. How steep is that color gradient? Even knowing that each unit change along the envelope is offset horizontally by <strong>&gamma;<sub>1</sub>=-&beta;<sub>2</sub>/&beta;<sub>1</sub></strong> isn't helpful, since it's not clear exactly where the unit changes in logC:N ratio are.

Our goal is to predict the PL application rate that will achieve maximum yield. We can predict this using the derived formulae from above. If you imagine the above figure as a 3d surface, you'd have been looking down the x-axis. Now we want to look down the z-axis:

![Along z-axis, annotated](/images/alongZanno.png)

Looking down at the model, we see a frontier that separates a plateau region to the upper left, and the response region to the lower right. This frontier can tell us: for a given quality of residue at spring termination, what is the minimum rate of PL to apply to achieve Yield<sub>max</sub>? For all our site years:

![Along z-axis with data](/images/alongZ.png)

While this figure is certainly more challenging to interpret, this frontier is its key strength. It's much clearer which combinations of conditions achieve maximum yield and which achieve suboptimal yield. 
