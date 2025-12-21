test_that("fetch_arxiv_data validates max_results parameter", {
  expect_error(
    fetch_arxiv_data(categories = "cs.CR", max_results = 0),
    "должен быть в диапазоне от 1 до 1000"
  )
  expect_error(
    fetch_arxiv_data(categories = "cs.CR", max_results = 1001),
    "должен быть в диапазоне от 1 до 1000"
  )
})

test_that("fetch_arxiv_data validates categories parameter", {
  expect_warning(
    fetch_arxiv_data(categories = c("cs.CR", "invalid.category"), max_results = 10),
    "Обнаружены недопустимые категории"
  )
  
  expect_error(
    fetch_arxiv_data(categories = c("invalid.category"), max_results = 10),
    "Не указано ни одной допустимой категории"
  )
})

test_that("fetch_arxiv_data handles network errors gracefully", {
  skip_if_not_installed("mockery")
  mockery::stub(
    fetch_arxiv_data,
    ".execute_arxiv_api_request",
    NULL
  )
  
  result <- fetch_arxiv_data(categories = "cs.CR", max_results = 10, verbose = FALSE)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("fetch_arxiv_data handles HTTP errors", {
  skip_if_not_installed("mockery")
  mock_response <- mock_http_response("", status_code = 500)
  
  mockery::stub(
    fetch_arxiv_data,
    ".execute_arxiv_api_request",
    mock_response
  )
  
  result <- fetch_arxiv_data(categories = "cs.CR", max_results = 10, verbose = FALSE)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("fetch_arxiv_data parses valid XML response", {
  skip_if_not_installed("mockery")
  xml_content <- get_sample_arxiv_xml()
  mock_response <- mock_http_response(xml_content)
  
  mockery::stub(
    fetch_arxiv_data,
    ".execute_arxiv_api_request",
    mock_response
  )
  
  result <- fetch_arxiv_data(categories = "cs.CR", max_results = 2, verbose = FALSE)
  
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2)
  expect_true(all(c("arxiv_id", "title", "authors", "abstract", "categories", 
                    "published_date", "doi", "collection_date") %in% names(result)))
})

test_that("fetch_arxiv_data extracts arxiv_id correctly", {
  skip_if_not_installed("mockery")
  xml_content <- get_sample_arxiv_xml()
  mock_response <- mock_http_response(xml_content)
  
  mockery::stub(
    fetch_arxiv_data,
    ".execute_arxiv_api_request",
    mock_response
  )
  
  result <- fetch_arxiv_data(categories = "cs.CR", max_results = 2, verbose = FALSE)
  
  expect_true("2412.12345v1" %in% result$arxiv_id)
  expect_true("2412.54321v2" %in% result$arxiv_id)
})

test_that("fetch_arxiv_data extracts DOI when available", {
  skip_if_not_installed("mockery")
  xml_content <- get_sample_arxiv_xml()
  mock_response <- mock_http_response(xml_content)
  
  mockery::stub(
    fetch_arxiv_data,
    ".execute_arxiv_api_request",
    mock_response
  )
  
  result <- fetch_arxiv_data(categories = "cs.CR", max_results = 2, verbose = FALSE)
  
  expect_true(any(!is.na(result$doi)))
  expect_true("https://doi.org/10.1234/example.doi" %in% result$doi)
})

test_that("fetch_arxiv_data handles empty XML response", {
  skip_if_not_installed("mockery")
  xml_content <- get_empty_arxiv_xml()
  mock_response <- mock_http_response(xml_content)
  
  mockery::stub(
    fetch_arxiv_data,
    ".execute_arxiv_api_request",
    mock_response
  )
  
  result <- fetch_arxiv_data(categories = "cs.CR", max_results = 10, verbose = FALSE)
  
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("filter_cybersecurity handles empty data", {
  empty_data <- tibble::tibble()
  
  expect_warning(
    result <- filter_cybersecurity(empty_data),
    "Входной набор данных пуст"
  )
  expect_equal(nrow(result), 0)
})

test_that("filter_cybersecurity filters by base keywords", {
  data <- get_sample_arxiv_data()
  
  result <- filter_cybersecurity(data, strict_mode = FALSE)
  
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
  expect_true(all(c("title", "abstract") %in% names(result)))
})

test_that("filter_cybersecurity filters correctly with strict_mode", {
  data <- get_sample_arxiv_data()
  
  result_strict <- filter_cybersecurity(data, strict_mode = TRUE)
  result_normal <- filter_cybersecurity(data, strict_mode = FALSE)
  
  expect_s3_class(result_strict, "tbl_df")
  expect_s3_class(result_normal, "tbl_df")
})

test_that("filter_cybersecurity excludes non-security papers", {
  data <- get_non_security_data()
  
  result <- filter_cybersecurity(data, strict_mode = FALSE)
  
  expect_equal(nrow(result), 0)
})

test_that("filter_cybersecurity preserves data structure", {
  data <- get_sample_arxiv_data()
  
  result <- filter_cybersecurity(data, strict_mode = FALSE)
  
  expect_true(all(names(data) %in% names(result)))
  expect_false("search_text" %in% names(result))
  expect_false("keyword_matches" %in% names(result))
})

test_that("save_collected_data handles empty data", {
  empty_data <- tibble::tibble()
  temp_file <- tempfile(fileext = ".rds")
  
  expect_warning(
    result <- save_collected_data(empty_data, temp_file),
    "Экспорт не выполнен"
  )
  expect_false(result)
})

test_that("save_collected_data validates file_path parameter", {
  data <- get_sample_arxiv_data()
  
  expect_error(
    save_collected_data(data, NULL),
    "Не указан путь для сохранения файла"
  )
  expect_error(
    save_collected_data(data, ""),
    "Не указан путь для сохранения файла"
  )
})

test_that("save_collected_data saves data successfully", {
  data <- get_sample_arxiv_data()
  temp_file <- tempfile(fileext = ".rds")
  
  result <- save_collected_data(data, temp_file, compress = FALSE)
  
  expect_true(result)
  expect_true(file.exists(temp_file))
  
  loaded_data <- readRDS(temp_file)
  expect_equal(nrow(loaded_data), nrow(data))
  expect_equal(names(loaded_data), names(data))
  
  unlink(temp_file)
})

test_that("save_collected_data creates directory if needed", {
  data <- get_sample_arxiv_data()
  temp_dir <- file.path(tempdir(), "test_subdir", "nested")
  temp_file <- file.path(temp_dir, "test.rds")
  
  result <- save_collected_data(data, temp_file)
  
  expect_true(result)
  expect_true(dir.exists(temp_dir))
  expect_true(file.exists(temp_file))
  
  unlink(temp_dir, recursive = TRUE)
})

test_that("save_collected_data handles compression parameter", {
  data <- get_sample_arxiv_data()
  temp_file_compressed <- tempfile(fileext = ".rds")
  temp_file_uncompressed <- tempfile(fileext = ".rds")
  
  save_collected_data(data, temp_file_compressed, compress = TRUE)
  save_collected_data(data, temp_file_uncompressed, compress = FALSE)
  
  expect_true(file.exists(temp_file_compressed))
  expect_true(file.exists(temp_file_uncompressed))
  
  size_compressed <- file.info(temp_file_compressed)$size
  size_uncompressed <- file.info(temp_file_uncompressed)$size
  
  expect_lt(size_compressed, size_uncompressed)
  
  unlink(temp_file_compressed)
  unlink(temp_file_uncompressed)
})

test_that(".construct_arxiv_query builds query for single category", {
  query <- arxivThreatIntel:::.construct_arxiv_query("cs.CR")
  expect_equal(query, "cat:cs.CR")
})

test_that(".construct_arxiv_query builds query for multiple categories", {
  query <- arxivThreatIntel:::.construct_arxiv_query(c("cs.CR", "cs.NI"))
  expect_match(query, "\\(cat:cs\\.CR OR cat:cs\\.NI\\)")
})

test_that(".parse_datetime handles valid datetime strings", {
  datetime_str <- "2024-12-15T12:00:00Z"
  result <- arxivThreatIntel:::.parse_datetime(datetime_str)
  
  expect_s3_class(result, "POSIXct")
  expect_false(is.na(result))
})

test_that(".parse_datetime handles invalid datetime strings", {
  invalid_str <- "invalid-date"
  result <- arxivThreatIntel:::.parse_datetime(invalid_str)
  
  expect_true(is.na(result))
})
