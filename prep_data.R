# PACKAGES =========
library(tidyverse)
library(magrittr)

# READ RESULTS =======
source("./scripts/readpcibex.R")

df <- read.pcibex("./raw_results.csv")
# df <- read.pcibex("~/Downloads/results_prod-8.csv")
df <- janitor::clean_names(df)

# Subject ID
df$subject <- with(df, paste(results_reception_time, md5_hash_of_participant_s_ip_address)) %>%
    as.factor() %>%
    as.integer() %>%
    sprintf("S[%s]", .) %>%
    as.factor()
df %<>% dplyr::select(-results_reception_time, -md5_hash_of_participant_s_ip_address)
#View(df)


# EXTRACT DEMOGRAPHICS ======
demo <- df %>% filter(label == "demo" & penn_element_type == "TextInput" & parameter == "Final")

demo <- demo %>% select("info" = penn_element_name, value, subject)

# filter the rows when penn_element_name is pid
demo <- demo %>% filter(info != "pid")



# Save demo data
write.csv(demo, "./results/demo.csv", row.names = FALSE)


# EXTRACT PRACTICE ITEMS ======
practice <- df %>%
    filter(str_detect(label, "^practice")) %>%
    filter(penn_element_type == "Controller-DashedSentence" | penn_element_type == "Scale")

practice <- practice %>%
    select(subject, label, penn_element_name, parameter, value, rt, type, trial_n, reading_time, itemnum)

head(practice)

write.csv(practice, "./results/practice.csv", row.names = FALSE)


# EXTRACT FILLER ITEMS ======
filler <- df %>%
    filter(label == "filler") %>%
    filter(penn_element_type == "Controller-DashedSentence" | penn_element_type == "Scale")

filler <- filler %>%
    select(label, penn_element_name, parameter, value, rt, person, condition, type, trial_n, reading_time, itemnum, subject)

head(filler)

write.csv(filler, "./results/filler.csv", row.names = FALSE)

# EXTRACT MAIN ITEMS ======
exp <- df %>%
    filter(label == "exp") %>%
    filter(penn_element_type == "Controller-DashedSentence" | penn_element_type == "Scale")

exp <- exp %>%
    select(label, penn_element_name, parameter, value, rt, person, condition, type, trial_n, itemnum, reading_time, subject, comma, v2)

# Reading Time Analysis
spr <- exp %>%
    filter(penn_element_name == "DashedSentence")
head(spr)
write.csv(spr, "./results/spr.csv", row.names = FALSE)

# Answer Analysis
ques <- exp %>%
    filter(penn_element_name == "grade")
head(ques)
write.csv(ques, "./results/ques.csv", row.names = FALSE)
