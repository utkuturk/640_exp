# PACKAGES =========
library(tidyverse)


# READ RESULTS =======

data <- read_csv("path_to_your_file.csv", col_types = cols(
    column1 = col_character(),
    column2 = col_double(),
    na = c("NA", "N/A", "na", "n/a", "NA", "N/A", "na", "n/a", "", " ", "NULL", "null", "Null")
))



# EXTRACT DEMOGRAPHICS ======
demo <- df %>% filter(label == "demo" & penn_element_type == "TextInput" & parameter == "Final")

demo <- demo %>% select(label, penn_element_name, value, prolific_id, subject)

# ! Check nonnative speakers
# ! Acquire age mean and range (min, max)
# ! remember all should be monolinguals


# EXTRACT PRACTICE ITEMS ======
practice <- df %>%
    filter(str_detect(label, "^practice")) %>%
    filter(penn_element_type == "Controller-DashedSentence" | penn_element_type == "Scale")

practice <- practice %>%
    select(label, penn_element_name, parameter, value, rt, type, trial_n, reading_time)


# ! check their answer to good_practice and bad practice items
# ! get the ones that are not very reliable
# ! filter their results out from the df


# EXTRACT FILLER ITEMS ======
filler <- df %>%
    filter(label == "filler") %>%
    filter(penn_element_type == "Controller-DashedSentence" | penn_element_type == "Scale")

filler <- filler %>%
    select(label, penn_element_name, parameter, value, rt, person, condition, type, trial_n, reading_time, subject)



# EXTRACT MAIN ITEMS ======
exp <- df %>%
    filter(label == "exp") %>%
    filter(penn_element_type == "Controller-DashedSentence" | penn_element_type == "Scale")

exp <- exp %>%
    select(label, penn_element_name, parameter, value, rt, person, condition, type, trial_n, reading_time, subject, comma, v2)



# EXCLUSIONS =====
# ! check accuracy of fillers
# ! check accuracy of practice items


# ANALYSIS =======

# Reading Time Analysis
spr <- exp %>%
    filter(penn_element_name == "DashedSentence")


# Answer Analysis
ques <- exp %>%
    filter(penn_element_name == "grade")


ques$value <- as.numeric(ques$value)
# Remove NAs from the data
ques_clean <- ques %>%
    filter(!is.na(value)) # Remove rows where 'value' is NA

# Summarize the data
summary_data <- ques_clean %>%
    group_by(condition, value) %>%
    summarise(count = n(), .groups = "drop") %>%
    mutate(rating = factor(value, levels = 7:1)) %>%
    mutate(myLabel = recode(condition,
                            "Base" = "Non-missing Verb RRC",
                            "Comma" = "Non-missing Verb ARC",
                            "MissingVBase" = "Missing Verb RRC",
                            "MissingVComma" = "Missing Verb ARC"))


# averages
q_avgs <- ques_clean %>%
    group_by(v2, comma) %>%
    summarise(
        rating = mean(value, na.rm = TRUE),
        sd = sd(value, na.rm = TRUE),
        n = n(),
        lower_ci = rating - qt(0.975, df = n - 1) * sd / sqrt(n),
        upper_ci = rating + qt(0.975, df = n - 1) * sd / sqrt(n)
    ) %>%
    mutate(
        myLabel = if_else(
            comma == "0",
            if_else(
                v2 == "0",
                "Missing Verb RRC",
                "Non-missing Verb RRC"
            ),
            if_else(
                v2 == "0",
                "Missing Verb ARC",
                "Non-missing Verb ARC"
            )
        )
        %>%
            factor(levels = c(
                "Missing Verb RRC",
                "Non-missing Verb RRC",
                "Missing Verb ARC",
                "Non-missing Verb ARC"
            ))
    )

# Calculate the cumulative count of each segment (relative to "fill" position)
summary_data_adjusted <- summary_data %>%
    group_by(myLabel) %>%
    mutate(
        cumulative_count = cumsum(count) / sum(count), # Normalize cumulative count to [0, 1]
        middle_of_bar = (cumsum(count) - count / 2) / sum(count)
    ) # Position at the center of each segment

# Plot the data
ggplot(summary_data, aes(x = myLabel, y = count, fill = rating)) +
    geom_bar(stat = "identity", position = "fill", color = "black", width = 0.8) +
    scale_fill_grey(start = 0.2, end = 0.8) +
    scale_x_discrete(expand = expansion(mult = c(0.2, 0.2))) +
    labs(y = NULL, x = NULL, fill = "Rating") +
    theme_minimal() +
    # Remove y-axis breaks and texts
    scale_y_continuous(labels = NULL, breaks = NULL) +
    # Print rating values for the "Missing Verb ARC" condition
    geom_text(
        data = summary_data_adjusted %>% filter(myLabel == "Missing Verb ARC"),
        aes(label = rating, y = middle_of_bar), # Position text at the center of each segment
        size = 4, hjust = 25, color = "black",fontface = "bold", vjust = 0.5 # Adjust vjust to center text vertically
    ) +
    theme(legend.position = "none")


total_q <- ques_clean %>%
    group_by(v2, comma) %>%
    dplyr::summarize(Total = n())

ques_clean$comma <- as.factor(ques_clean$comma)
ques_clean$v2 <- as.factor(ques_clean$v2)

dist_q <- ques_clean %>%
    group_by(v2, comma, value) %>%
    dplyr::summarize(Count = n()) %>%
    left_join(total_q) %>%
    mutate(
        Prop = Count / Total,
        myLabel = if_else(
             comma == "0",
             if_else(
                v2 == "0",
                "Missing Verb RRC",
                "Non-missing Verb RRC"
             ),
             if_else(
                v2 == "0",
                "Missing Verb ARC",
                "Non-missing Verb ARC"
             )
             )
           %>%
             factor(levels = c(
                "Missing Verb RRC",
                "Non-missing Verb RRC",
                "Missing Verb ARC",
                "Non-missing Verb ARC"
             )))

dist_q$rating <- dist_q$value

dist_q$rating <- as.factor(dist_q$rating)

# dist_q <- dist_q %>%
#     left_join(q_avgs %>% select(v2, comma, lower_ci, upper_ci), by = c("v2", "comma"))

ggplot(dist_q) +
    aes(
        x = rating,
        color = rating,
        y = Prop # Use the Prop variable from dist_q
    ) +
    geom_vline(
        data = q_avgs,
        mapping = aes(xintercept = rating),
        colour = "black"
    )  +
    geom_point(stat = "identity", size = 2) +
    scale_x_discrete() +
    facet_wrap(vars(myLabel), ncol =1 ) +
    scale_y_continuous(limits = c(0, 0.3)) +
    scale_color_grey(
        start = 0.8, end = 0.2,
        guide = "none"
    ) +
    labs(
        title = "Naturalness",
        y = "Proportion of Responses",
        x = "Response"
    ) +
    theme_bw() +
    theme(
        strip.background = element_rect(fill = "black"),
        strip.text = element_text(color = "white")
    )




# Question Answer Analysis
# ! Get the correct answers.
ques$rt <- as.numeric(ques$rt)
qa_avgs <- ques %>%
    group_by(v2, comma) %>%
    summarise(
        mean = mean(rt, na.rm = TRUE),
        sd = sd(rt, na.rm = TRUE),
        n = n(),
        lower_ci = mean - qt(0.975, df = n - 1) * sd / sqrt(n),
        upper_ci = mean + qt(0.975, df = n - 1) * sd / sqrt(n)
    ) %>%
    mutate(
        myLabel = if_else(
            comma == "0",
            if_else(
                v2 == "0",
                "Missing Verb RRC",
                "Non-missing Verb RRC"
            ),
            if_else(
                v2 == "0",
                "Missing Verb ARC",
                "Non-missing Verb ARC"
            )
        )
        %>%
            factor(levels = c(
                "Missing Verb RRC",
                "Non-missing Verb RRC",
                "Missing Verb ARC",
                "Non-missing Verb ARC"
            ))
    )

# plot qa_avgs with v2 and comma, have the lower ci and upper ci as a error bar. have the mean as a point, make the plot look nice, and make the facetwrap with v2
ggplot(qa_avgs) +
    aes(
        x = v2,
        y = mean,
        color = v2
    ) +
    geom_errorbar(
        aes(ymin = lower_ci, ymax = upper_ci),
        width = 0.2
    ) +
    geom_point(stat = "identity", size = 2) +
    facet_wrap(~comma) +
    labs(
        title = "Naturalness",
        y = "Response Time",
        x = "Response"
    ) +
    theme_bw() +
    theme(
        strip.background = element_rect(fill = "black"),
        strip.text = element_text(color = "white")
    )



#### Model

# family can be cumulati, sratio

brm(formula, rating ~ c1 + c2 + cs(c3), data = data, family = cumulative, )


### Cutpoints Plotting
# Extract posterior samples for cutpoints only
cutpoints <- as_draws_df(fit) %>%
    select(matches("^b_Intercept\\[\\d+\\]$")) %>%
    pivot_longer(everything(), names_to = "Cutpoint", values_to = "Value") %>%
    mutate(Cutpoint = str_remove_all(Cutpoint, "b_Intercept\\[|\\]"))

summary_cutpoints <- cutpoints %>%
    group_by(Cutpoint) %>%
    summarise(
        Mean = mean(Value),
        CI_lower = quantile(Value, 0.025),
        CI_upper = quantile(Value, 0.975)
    )

print(summary_cutpoints)

ggplot(cutpoints, aes(x = Value, fill = Cutpoint)) +
    geom_density(alpha = 0.7) +
    theme_minimal() +
    labs(
        title = "Posterior Distributions of Cutpoints",
        x = "Cutpoint Value",
        y = "Density"
    ) +
    facet_wrap(~Cutpoint, scales = "free_x") +
    scale_fill_brewer(palette = "Set3")



## Model Coefficient Plotting

{
    library(bayesplot)
    library(ggplot2)
    library(dplyr)
    library(tidyr)
    library(ggtext)
    # Create a mapping of original effect names to concise labels
    effect_labels <- c(
        "b_v_n" = "Verb Number",
        "b_att_n" = "Attractor Number",
        "b_register" = "Register",
        "b_v_n:att_n" = "Verb x Attractor Number",
        "b_v_n:att_n:register" = "3-way interaction"
    )

    # Assuming 'fit' is your Bayesian model fit object
    post_samples <- as_draws_df(fit)

    # Filter the relevant parameters
    post_samples_filtered <- post_samples[, c("b_v_n", "b_att_n", "b_register", "b_v_n:att_n", "b_v_n:att_n:register")]

    # Calculate the means and credible intervals
    post_samples_summary <- post_samples_filtered %>%
        summarise(across(everything(),
            list(
                mean = ~ mean(.),
                lower = ~ quantile(., 0.025),
                upper = ~ quantile(., 0.975)
            ),
            .names = "{.col}_{.fn}"
        ))

    # Reshape the summary data using pivot_longer()
    post_samples_summary_long <- post_samples_summary %>%
        pivot_longer(
            cols = everything(),
            names_to = c("Effect", "stat"),
            names_pattern = "(.+)_(mean|lower|upper)$", # Regex to capture all before last underscore and the stat
            values_to = "value"
        ) %>%
        dplyr::filter(stat %in% c("mean", "lower", "upper")) %>%
        pivot_wider(names_from = stat, values_from = value)

    # Replace Effect names with concise labels
    post_samples_summary_long <- post_samples_summary_long %>%
        mutate(Effect = recode(Effect, !!!effect_labels))

    # Calculate probabilities of effects being >0 and <0
    probabilities <- post_samples_filtered %>%
        summarise(across(everything(),
            list(
                prob_gt = ~ mean(. > 0),
                prob_lt = ~ mean(. < 0)
            ),
            .names = "{.col}_prob_{.fn}"
        )) %>%
        pivot_longer(
            cols = everything(),
            names_to = c("Effect", "prob_type"),
            names_pattern = "(.+)_prob_(.+)",
            values_to = "probability"
        )

    # delete the last 5 characters from Effect colum
    probabilities$Effect <- substr(probabilities$Effect, 1, nchar(probabilities$Effect) - 5)


    # Clean Effect names for the probabilities
    probabilities <- probabilities %>%
        mutate(Effect = recode(Effect, !!!effect_labels))


    # Create a combined dataset for plotting
    combined_data <- post_samples_summary_long %>%
        left_join(probabilities, by = "Effect")
    # Load necessary libraries
    library(ggplot2)
    library(dplyr)
    library(ggtext) # Add ggtext for enhanced text formatting

    # Prepare combined_data with labels that include probabilities
    combined_data <- combined_data %>%
        group_by(Effect) %>%
        summarize(
            mean = first(mean),
            lower = first(lower),
            upper = first(upper),
            prob_gt = first(probability[prob_type == "gt"]),
            prob_lt = first(probability[prob_type == "lt"]),
            .groups = "drop"
        ) %>%
        mutate(
            # Concatenate the probability label
            label = case_when(
                round(prob_gt, 2) == 1 ~ "P(> 0): >0.99",
                round(prob_gt, 2) == 0 ~ "P(< 0): >0.99",
                prob_gt > 0 ~ paste("P(> 0):", round(prob_gt, 2)),
                prob_lt > 0 ~ paste("P(< 0):", round(prob_lt, 2)),
                TRUE ~ NA_character_ # Ensure NA for any unmatched cases
            )
        )

    # Specify the order of effects for the y-axis
    effect_order <- c(
        "3-way interaction", "Verb x Attractor Number", "Register", "Attractor Number", "Verb Number"
    )

    # Create the plot with ROPE and annotations
    ggplot(combined_data, aes(x = mean, y = factor(Effect, levels = effect_order))) + # Set y-axis order
        geom_point(size = 3) + # Plot means as points
        geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.2) + # Error bars for credible intervals
        # geom_text(aes(label = label), hjust = 0.8, vjust = -1.5, size = 3.5, check_overlap = TRUE, family = "mono") + # Annotate probabilities with monospaced font
        geom_vline(xintercept = 0, linetype = "dashed", color = "black", size = 1.2, alpha = 0.4) + # Bold vertical line at zero
        theme_classic() +
        geom_hline(yintercept = 0, linetype = "solid", color = "black", size = 0.5) + # Horizontal line just above x-axis
        theme(
            plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
            axis.text.y = element_text(size = 12, color = "black"), # Default font for effect names
            axis.text.x = element_text(size = 12, color = "black"),
            axis.title.x = element_text(size = 14, face = "bold"),
            axis.title.y = element_text(size = 14, face = "bold"),
            panel.grid.major.x = element_line(color = "gray80", size = 0.5),
            panel.grid.minor.x = element_line(color = "gray90", size = 0.5),
            panel.grid.minor = element_blank()
        ) +
        labs(x = "Estimate (logit)", y = "", title = "") +
        scale_y_discrete(labels = function(x) {
            labels_with_probs <- paste0(x, "\n ", combined_data$label[match(x, combined_data$Effect)], "")
            labels_with_probs[is.na(labels_with_probs)] <- ""
            return(labels_with_probs)
        }) +
        theme(axis.text.y = element_text(size = 12))
}
