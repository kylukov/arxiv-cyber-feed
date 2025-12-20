

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

# 2. ТЕСТЫ ДЛЯ filter_cybersecurity()

test_that("filter_cybersecurity корректно фильтрует данные", {
  test_data <- tibble(
    arxiv_id = c("2401.001", "2401.002", "2401.003"),
    title = c(
      "Advanced Security Protocols for Networks",
      "Machine Learning for Image Processing",
      "Cryptography Methods in Cloud Computing"
    ),
    abstract = c(
      "New security approaches for modern networks.",
      "Deep learning techniques for computer vision.",
      "Encryption and data protection in cloud environments."
    ),
    authors = list(c("Author1"), c("Author2"), c("Author3")),
    categories = list(c("cs.CR"), c("cs.AI"), c("cs.CR")),
    published_date = as.POSIXct(rep("2024-01-01", 3)),
    doi = rep(NA_character_, 3),
    collection_date = as.POSIXct(rep("2024-01-01", 3))
  )
  
  filtered <- filter_cybersecurity(test_data, strict_mode = FALSE)
  
  expect_equal(nrow(filtered), 2)
  
  expect_true("2401.001" %in% filtered$arxiv_id)  
  expect_true("2401.003" %in% filtered$arxiv_id)  
  expect_false("2401.002" %in% filtered$arxiv_id) 
})

test_that("filter_cybersecurity обрабатывает пустые данные", {
  empty_data <- tibble()
  
  expect_warning(
    filter_cybersecurity(empty_data),
    "Входной набор данных пуст"
  )
  
  result <- suppressWarnings(filter_cybersecurity(empty_data))
  expect_equal(nrow(result), 0)
  expect_s3_class(result, "tbl_df")
})

test_that("filter_cybersecurity работает в строгом режиме", {
  test_data <- tibble(
    arxiv_id = c("2401.004", "2401.005"),
    title = c(
      "APT Detection Using Threat Intelligence",
      "Network Traffic Analysis"
    ),
    abstract = c(
      "Advanced persistent threat detection methods using threat intelligence.",
      "Analysis of network traffic patterns for performance optimization."
    ),
    authors = list(c("Author1"), c("Author2")),
    categories = list(c("cs.CR"), c("cs.NI")),
    published_date = as.POSIXct(rep("2024-01-01", 2)),
    doi = rep(NA_character_, 2),
    collection_date = as.POSIXct(rep("2024-01-01", 2))
  )
  
  strict_filtered <- filter_cybersecurity(test_data, strict_mode = TRUE)
  expect_equal(nrow(strict_filtered), 1)
  expect_equal(strict_filtered$arxiv_id, "2401.004")
  
  basic_filtered <- filter_cybersecurity(test_data, strict_mode = FALSE)
})

test_that("filter_cybersecurity правильно сортирует по количеству совпадений", {
  test_data <- tibble(
    arxiv_id = c("2401.006", "2401.007", "2401.008"),
    title = c(
      "Network Security",
      "Encryption and Authentication",
      "Comprehensive Security and Cryptography Framework"
    ),
    abstract = c(
      "This paper discusses network security.",
      "This paper covers encryption methods and authentication protocols.",
      "This paper presents a framework combining security, cryptography, and data protection."
    ),
    authors = list(c("Author1"), c("Author2"), c("Author3")),
    categories = list(c("cs.CR"), c("cs.CR"), c("cs.CR")),
    published_date = as.POSIXct(rep("2024-01-01", 3)),
    doi = rep(NA_character_, 3),
    collection_date = as.POSIXct(rep("2024-01-01", 3))
  )
  
  filtered <- filter_cybersecurity(test_data, strict_mode = FALSE)
  
  expect_equal(nrow(filtered), 3)
  
  expect_equal(filtered$arxiv_id[1], "2401.008")
  expect_equal(filtered$arxiv_id[3], "2401.006")
})

# 3. ТЕСТЫ ДЛЯ save_collected_data()


test_that("save_collected_data сохраняет и загружает данные", {
  test_data <- tibble(
    arxiv_id = "2401.001",
    title = "Test Publication",
    abstract = "Test abstract content with security keywords",
    authors = list(c("Test Author")),
    categories = list(c("cs.CR")),
    published_date = as.POSIXct("2024-01-01"),
    doi = NA_character_,
    collection_date = as.POSIXct("2024-01-01")
  )
  
  temp_file <- tempfile(fileext = ".rds")
  save_result <- save_collected_data(test_data, temp_file)
  
  expect_true(save_result)
  expect_true(file.exists(temp_file))
  
  loaded_data <- readRDS(temp_file)
  expect_equal(nrow(loaded_data), nrow(test_data))
  expect_equal(loaded_data$arxiv_id, test_data$arxiv_id)
  
  unlink(temp_file)
})

test_that("save_collected_data создает директории", {
  test_data <- tibble(
    arxiv_id = "2401.002",
    title = "Another Test",
    abstract = "Abstract with encryption mentioned",
    authors = list(c("Author")),
    categories = list(c("cs.CR")),
    published_date = as.POSIXct("2024-01-01"),
    doi = NA_character_,
    collection_date = as.POSIXct("2024-01-01")
  )
  
  nested_path <- file.path(tempdir(), "test", "nested", "data.rds")
  save_result <- save_collected_data(test_data, nested_path)
  
  expect_true(save_result)
  expect_true(file.exists(nested_path))
  
  unlink(dirname(nested_path), recursive = TRUE)
})

test_that("save_collected_data обрабатывает ошибки", {
  expect_warning(
    save_collected_data(tibble(), "test.rds"),
    "Экспорт не выполнен"
  )
  
  expect_error(
    save_collected_data(tibble(arxiv_id = "test"), ""),
    "Не указан путь для сохранения файла"
  )
})

# 4. ТЕСТЫ ВСПОМОГАТЕЛЬНЫХ ФУНКЦИЙ

test_that(".construct_arxiv_query формирует корректные запросы", {
  expect_equal(.construct_arxiv_query("cs.CR"), "cat:cs.CR")
  expect_equal(
    .construct_arxiv_query(c("cs.CR", "cs.AI")),
    "(cat:cs.CR OR cat:cs.AI)"
  )
  expect_equal(
    .construct_arxiv_query(c("cs.CR", "cs.AI", "cs.NI")),
    "(cat:cs.CR OR cat:cs.AI OR cat:cs.NI)"
  )
})

test_that(".parse_datetime корректно парсит даты", {
  test_date <- "2024-01-15T12:30:45Z"
  parsed <- .parse_datetime(test_date)
  
  expect_s3_class(parsed, "POSIXct")
  expect_equal(format(parsed, "%Y-%m-%d"), "2024-01-15")
  
  invalid <- .parse_datetime("not-a-date")
  expect_true(is.na(invalid))
})

# 5. ИНТЕГРАЦИОННЫЕ ТЕСТЫ

test_that("Полный ETL цикл работает корректно", {
  skip_if_offline()
  skip_if(httr::http_error("http://export.arxiv.org"))
  
  raw_data <- fetch_arxiv_data(
    categories = "cs.CR",
    max_results = 5,
    verbose = FALSE
  )
  
  if (nrow(raw_data) > 0) {
    filtered <- filter_cybersecurity(raw_data, strict_mode = FALSE)
    expect_lte(nrow(filtered), nrow(raw_data))
    
    temp_file <- tempfile(fileext = ".rds")
    save_result <- save_collected_data(filtered, temp_file)
    expect_true(save_result)
    
    if (file.exists(temp_file)) {
      loaded <- readRDS(temp_file)
      expect_equal(nrow(filtered), nrow(loaded))
      unlink(temp_file)
    }
  }
})

test_that("Функции работают с реальными данными arXiv", {
  skip_if_offline()
  skip_if(httr::http_error("http://export.arxiv.org"))
  
  data <- fetch_arxiv_data(max_results = 3, verbose = FALSE)
  
  if (nrow(data) > 0) {
    expect_true(all(grepl("^\\d{4}\\.\\d{4,5}", data$arxiv_id)))
    
    expect_false(all(is.na(data$published_date)))
    
    expect_true(all(sapply(data$authors, is.character)))
    expect_true(all(sapply(data$categories, is.character)))
    
    expect_true(all(!is.na(data$collection_date)))
  }
})

# 6. ТЕСТЫ ПРОИЗВОДИТЕЛЬНОСТИ

test_that("Операции выполняются за разумное время", {
  skip_if_offline()
  skip_if(httr::http_error("http://export.arxiv.org"))
  
  time_result <- system.time({
    fetch_arxiv_data(max_results = 2, verbose = FALSE)
  })
  
  expect_lt(time_result["elapsed"], 10)
  
  data <- fetch_arxiv_data(max_results = 5, verbose = FALSE)
  if (nrow(data) > 0) {
    filter_time <- system.time({
      filter_cybersecurity(data)
    })
    expect_lt(filter_time["elapsed"], 2)
  }
})


# 7. ТЕСТЫ КРАЕВЫХ СЛУЧАЕВ


test_that("Обработка краевых случаев", {
  skip_if_offline()
  skip_if(httr::http_error("http://export.arxiv.org"))
  
  minimal_data <- fetch_arxiv_data(max_results = 1, verbose = FALSE)
  expect_lte(nrow(minimal_data), 1)
  
  if (interactive()) {  # Только в интерактивном режиме
    large_data <- fetch_arxiv_data(max_results = 100, verbose = FALSE)
    expect_lte(nrow(large_data), 100)
  }
})