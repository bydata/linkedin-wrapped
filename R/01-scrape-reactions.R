library(tidyverse)
library(rvest)
library(here)

# If sourced from the Quarto doc, from_date will already be set
if (!exists("from_date")) {
  from_date <- as_date("2024-01-01")
  to_date <- as_date("2024-12-31")
}

# Read post URLs
paths_complete_export_zip <- list.files("data", pattern = "Complete_LinkedInDataExport_.+\\.zip")
path_complete_export <- here("data", "complete_data")
unzip(here("data", paths_complete_export_zip[1]), exdir = path_complete_export, 
      files = c("Shares.csv"))

df_posts <- read_csv(here(path_complete_export, "Shares.csv"))
# Exclude posts without text since they typically are reposts
#TODO
df_posts <- df_posts[!is.na(df_posts$ShareCommentary), ]
urls <- df_posts$ShareLink[df_posts$Date >= from_date & df_posts$Date <= to_date]


# Extract reactions count from page
extract_reactions_count <- function(x) {
  selector_reactions <- "section > article:nth-of-type(1) span[data-test-id='social-actions__reaction-count']"
  
  x |> 
    html_nodes(css = selector_reactions) |> 
    html_text() |> 
    str_squish() |> 
    str_remove_all("[,.]") |> 
    as.integer()
}

# Extract comments count from page
extract_comments_count <- function(x) {
  selector_comments <- "section > article:nth-of-type(1) a[data-test-id='social-actions__comments']"
  
  x |> 
    html_nodes(css = selector_comments) |> 
    html_text() |> 
    str_squish() |> 
    str_remove("\\sComments?") |> 
    str_remove_all("[,.]") |> 
    as.integer()
}

extract_data <- function(url) {
  # Get the page content
  page <- read_html(url)
  post_id_pattern <- "%3A(?:share|ugcPost)%3A(\\d+)"
  post_id <- str_extract(url, post_id_pattern, group = 1)
  n_reactions <- extract_reactions_count(page)
  n_comments <- extract_comments_count(page)
  data.frame(post_id = post_id, post_url = url, 
             reactions = ifelse(is.null(n_reactions) || is.na(n_reactions), 0, n_reactions),
             comments = ifelse(is.null(n_comments) || is.na(n_comments), 0, n_comments)
  )
}

extract_data_safely <- safely(extract_data)
df_reactions_comments <- map(urls, extract_data_safely)

df_reactions_comments_results <- df_reactions_comments |> 
  transpose() |> 
  pluck("result") |> 
  bind_rows() |> 
  mutate(
    across(c(reactions, comments), function(x) replace_na(x, 0))
  )
write_csv(df_reactions_comments_results, here("data", "post-reactions.csv"))

# Add reactions and comments stats to post dataset
df_post_stats <- df_posts |> 
  inner_join(df_reactions_comments_results, 
             by = join_by(ShareLink == post_url)) |> 
  janitor::clean_names()
write_csv(df_post_stats, here("data", "post-stats.csv"))
