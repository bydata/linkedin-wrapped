library(tidyverse)
library(ggtext)

df_post_stats <- read_csv(file.path("data", "post-stats.csv"))
df_post_stats <- df_post_stats |> 
  # janitor::clean_names() |> 
  mutate(
    datetime = date,
    date = as_date(date),
    month = month(date, label = TRUE)
  ) |> 
  select(datetime, date, everything())

# Number of posts
(n_posts <- nrow(df_post_stats))

# Number of reactions
(n_total_reactions <- sum(df_post_stats$reactions))

# Number of comments
(n_total_comments <- sum(df_post_stats$comments))

# Top posts by number of reactions
df_post_stats |> 
  slice_max(order_by = reactions, n = 3) |> 
  select(date, share_commentary, reactions, comments)

# Calendar of post dates
df_calendar_plot <- df_post_stats |> 
  transmute(
    date = as_date(date)
  ) |> 
  group_by(date) |> 
  summarize(n_posts = n()) |> 
  complete(
    date = seq(as_date("2024-01-01"), as_date("2024-12-31"), "1 day"),
    fill = list(n_posts = 0)) |> 
  mutate(
    week = isoweek(date),
    week_start_date = floor_date(date, "1 week", week_start = 1),
    week_start_date = as_date(week_start_date),
    week_start_month_num = month(week_start_date),
    week_start_month = month(week_start_date, label = TRUE),
    weekday_num = wday(date, label = FALSE, week_start = 1),
    weekday = wday(date, label = TRUE, week_start = 1),
    week = ifelse(week == 1 & week_start_month_num == 12, 53, week)
  ) |> 
  arrange(date)


gradient_fill <- grid::linearGradient(c("#352461", "#11052F"))

# Find the week nums for the month labels
df_first_week_of_month <- df_calendar_plot |> 
  group_by(week_start_month) |> 
  summarize(first_week_of_month = min(week))
first_week_of_month <- df_first_week_of_month$first_week_of_month
names(first_week_of_month) <- df_first_week_of_month$week_start_month
first_week_of_month

df_calendar_plot |> 
  # mutate(n_posts = na_if(n_posts, 0)) |> 
  ggplot(aes(week, weekday_num)) +
  geom_tile(
    aes(fill = n_posts),
    height = 0.8, width = 0.8) +
  scale_x_continuous(
    breaks = first_week_of_month
  ) +
  scale_y_reverse(
    expand = c(0,0), breaks = 1:7, labels = unique(df_calendar_plot$weekday)) +
  scale_fill_viridis_c(option = "plasma", na.value = "grey80") +
  coord_fixed() +
  guides(fill = guide_legend(
    override.aes = list(shape = 22, color = "white", size = 2))) +
  theme_minimal(base_family = "Roboto Condensed") +
  theme(
    plot.background = element_rect(color = gradient_fill, fill = gradient_fill),
    panel.grid = element_blank(),
    text = element_text(color = "white"),
    axis.text = element_text(color = "white"),
    axis.text.y = element_text(hjust = 0),
    legend.position = "bottom",
    legend.key.width = unit(0.05, "npc"),
    legend.key.height = unit(0.05, "npc")
  )


# Top posts per month (based on reactions)
share_commentary_short_size <- 120
df_post_stats |> 
  group_by(month) |> 
  slice_max(order_by = reactions, n = 1, with_ties = FALSE) |> 
  ungroup() |> 
  mutate(
    share_commentary = str_replace_all(share_commentary, "\"", " "),
    share_commentary_short = str_sub(share_commentary, 1, share_commentary_short_size),
    share_commentary_short = ifelse(
      str_length(share_commentary < share_commentary_short_size),
      paste0(share_commentary_short, "..."),
      share_commentary)
  ) |> 
  ggplot(aes(0, 0)) +
  geom_textbox(
    aes(label = share_commentary_short),
    width = 0.9, size = 2.5, family = "Roboto Condensed"
  ) +
  facet_wrap(vars(month),  strip.position = "left") +
  theme_void(base_family = "Roboto Condensed") +
  theme(
    strip.text = element_text(size = 12)
  )

