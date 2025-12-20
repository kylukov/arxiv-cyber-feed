

library(testthat)
library(httr)
library(xml2)
library(dplyr)
library(stringr)
library(tibble)
library(lubridate)
library(purrr)

source("~/Desktop/arxiv-cyber-feed/R/collect_data.R")


# 1. ТЕСТЫ ДЛЯ fetch_arxiv_data()
 
test_that("fetch_arxiv_data возвращает корректную структуру", {
   skip_if_offline()
  skip_if(httr::http_error("http://export.arxiv.org"))
  
   test_data <- fetch_arxiv_data(max_results = 2, verbose = FALSE)
  
   expect_s3_class(test_data, "tbl_df")
  
   expected_cols <- c("arxiv_id", "title", "authors", "abstract", 
                     "categories", "published_date", "doi", "collection_date")
  expect_named(test_data, expected_cols, ignore.order = TRUE)
})

test_that("fetch_arxiv_data валидирует параметры", {
  expect_error(
    fetch_arxiv_data(max_results = 0, verbose = FALSE),
    "Параметр max_results должен быть в диапазоне"
  )
  
  expect_error(
    fetch_arxiv_data(max_results = 2000, verbose = FALSE),
    "Параметр max_results должен быть в диапазоне"
  )
  
  expect_warning(
    fetch_arxiv_data(categories = c("cs.CR", "invalid.category"), verbose = FALSE),
    "Обнаружены недопустимые категории"
  )
  
  expect_error(
    {
      suppressWarnings(
        fetch_arxiv_data(categories = "invalid.category", verbose = FALSE)
      )
    },
    "Не указано ни одной допустимой категории"
  )
  
  # Тест error для пустого вектора
  expect_error(
    fetch_arxiv_data(categories = character(0), verbose = FALSE),
    "Не указано ни одной допустимой категории"
  )
})

test_that("fetch_arxiv_data работает с несколькими категориями", {
  skip_if_offline()
  skip_if(httr::http_error("http://export.arxiv.org"))
  
  data <- fetch_arxiv_data(
    categories = c("cs.CR", "cs.AI"),
    max_results = 3,
    verbose = FALSE
  )
  
  if (nrow(data) > 0) {
    expect_true(all(grepl("^\\d{4}\\.\\d{4,5}", data$arxiv_id)))
    
    expect_type(data$title, "character")
    expect_type(data$authors, "list")
    expect_type(data$abstract, "character")
    expect_s3_class(data$published_date, "POSIXct")
  }
})

