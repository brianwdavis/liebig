library(ggplot2)
library(dplyr)

set.seed(2)
temp <- expand.grid(pl = c(0, 70, 140, 210, 280),
                    logcn = seq(log(11), log(138), length.out = 7),
                    block = LETTERS[1:4]) %>% 
  group_by(block) %>% 
  mutate(logcn = logcn + rnorm(length(logcn), sd = 0.1),
         plotID = paste0(block, 10+sample.int(length(pl))),
         bleffect = rnorm(1, sd = 2))

temp %>% mutate(CN = exp(logcn)) %>% 
  summarise_all(funs(min, max))

demo_df <- temp %>% 
  mutate(yield = pmin(16+0.05*pl + -2.6*logcn, 13 - bleffect) + 
           rnorm(length(pl)),
         CN = exp(logcn)) %>% 
  dplyr::select(block, plotID, CN, pl, yield)

demo_df %>% 
  ggplot(aes(pl, yield, color = CN)) + 
  geom_point() + facet_wrap(~cut(log(CN), 7))

readr::write_csv(demo_df, "./demo_df.csv")
