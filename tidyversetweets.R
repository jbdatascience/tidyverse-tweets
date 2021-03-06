### Setup ----------------------------------------------------------------------
library(tidyverse)
library(glue)
library(lubridate)
library(stackr)
library(feedeR)
library(rtweet)


### Query Stackoverflow API ----------------------------------------------------
safe_query <- safely(stack_questions)
query_tag <- function(tag) {
  query <- safe_query(pagesize = 100, tagged = tag)
  return(query)
}
query_community <- function(category) {
  query <- feed.extract(glue("https://community.rstudio.com/c/{category}.rss"))
  return(query)
}

tidyverse <- c("tidyverse", "ggplot2", "dplyr", "tidyr", "readr", "purrr",
  "tibble", "readxl", "haven", "jsonlite", "xml2", "httr", "rvest", "DBI;r",
  "stringr", "lubridate", "forcats", "hms", "blob;r", "rlang", "magrittr",
  "glue", "recipes", "rsample", "modelr")

Sys.setenv(TZ = "America/Chicago")
cur_time <- ymd_hms(Sys.time(), tz = Sys.timezone())

source("~/.Rprofile")

tidy_so <- map(tidyverse, query_tag) %>%
  map_dfr(~(.$result %>% as.tibble())) %>%
  select(title, creation_date, link) %>%
  mutate(
    title = str_replace_all(title, "&#39;", "'"),
    title = str_replace_all(title, "&quot;", '"'),
    title = str_replace_all(title, "&amp;&#160;", "& "),
    title = str_replace_all(title, "&gt;", ">"),
    title = str_replace_all(title, "&lt;", "<"),
    title = str_replace_all(title, "&amp;", "&")
  ) %>%
  distinct() %>%
  mutate(creation_date = with_tz(creation_date, tz = "America/Chicago")) %>%
  arrange(creation_date)

rstudio <- c("tidyverse", "teaching")

tidy_rc <- map(rstudio, query_community) %>%
  map_dfr(~(.$items %>% as.tibble())) %>%
  select(title, creation_date = date, link) %>%
  mutate(creation_date = with_tz(creation_date, tz = "America/Chicago")) %>%
  group_by(title) %>%
  top_n(n = -1, wt = creation_date) %>%
  arrange(creation_date)

all_update <- bind_rows(tidy_so, tidy_rc) %>%
  arrange(creation_date) %>%
  filter(creation_date > cur_time - dminutes(5)) %>%
  as.list()

pwalk(.l = all_update, .f = function(title, creation_date, link) {
  if (nchar(title) > 250) {
    trunc_points <- str_locate_all(title, " ") %>%
      .[[1]] %>%
      .[,1]
    trunc <- max(trunc_points[which(trunc_points < 247)]) - 1
    title <- paste0(str_sub(title, start = 1, end = trunc), "...")
  }
  
  tweet_text <- glue("{title} #tidyverse #rstats {link}")
  post_tweet(tweet_text, token = read_rds("~/.rtweet_token2.rds"))
})
