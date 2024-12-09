# packages
library(tidyverse)
library(brms)

heyutku <- function(path) {
  read_csv(path, na=c("NA", "N/A", "", " ", "null", "NULL", NULL, "Null", "na", "n/a"))
}
getwd()

answers = heyutku("./results/ques.csv")

str(answers)
summary(answers)

answers$subject %>% unique() %>% length()
max(answers$itemnum)

answers$condition <- as.factor(answers$condition)


summary_data = answers %>%
  dplyr::group_by(condition) %>%
  dplyr::summarise(
    mean = mean(value, na.rm = TRUE),
    sd = sd(value, na.rm = TRUE),
    n = n(),
    se = 1.96 * sd / sqrt(n)
  )

ggplot(summary_data, aes(x = condition, y = mean)) +
  geom_point() +
  geom_errorbar(aes(ymin = mean - se, ymax = mean + se))


library(brms)

answers$value <- as.integer(answers$value)
answers$comma <- as.factor(answers$comma)
answers$v2 <- as.factor(answers$v2)
answers$subjects <- as.factor(answers$subject)
answers$itemnum <- as.factor(answers$itemnum)


fit = brm(
  formula = value ~ 1 + comma * v2 + (1 + comma * v2 | subject) + (1 + comma * v2 | itemnum),
  family = cumulative,
  data = answers,
  file = "myfit",
  chains = 4,
  iter = 2000,
  warmup = 1000
)

summary(fit)
