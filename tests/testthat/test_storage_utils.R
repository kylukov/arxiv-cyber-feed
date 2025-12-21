test_that("normalize produces three tables", {
  df <- tibble::tibble(
    arxiv_id = "2412.12345",
    title = "Test",
    abstract = "Security paper",
    categories = list(c("cs.CR","cs.NI")),
    authors = list(c("Alice","Bob")),
    published_date = Sys.time(),
    doi = NA_character_,
    collection_date = Sys.time()
  )
  res <- normalize_arxiv_records(df)
  expect_true(all(c("articles","authors","categories") %in% names(res)))
  expect_gt(nrow(res$articles), 0)
  expect_gt(nrow(res$authors), 0)
  expect_gt(nrow(res$categories), 0)
})

test_that("normalize_arxiv_records handles empty data", {
  empty_df <- tibble::tibble()
  
  expect_warning(
    result <- normalize_arxiv_records(empty_df),
    "Нет данных для нормализации"
  )
  
  expect_type(result, "list")
  expect_true(all(c("articles", "authors", "categories", "security_categories") %in% names(result)))
  expect_equal(nrow(result$articles), 0)
  expect_equal(nrow(result$authors), 0)
  expect_equal(nrow(result$categories), 0)
})

test_that("normalize_arxiv_records works with primary mode categorization", {
  data <- get_categorized_data_primary()
  
  result <- normalize_arxiv_records(data)
  
  expect_true("articles" %in% names(result))
  expect_true("authors" %in% names(result))
  expect_true("categories" %in% names(result))
  expect_true("security_category" %in% names(result$articles))
  expect_true("category_confidence" %in% names(result$articles))
  expect_equal(nrow(result$articles), nrow(data))
})

test_that("normalize_arxiv_records works with multi mode categorization", {
  data <- get_categorized_data_multi()
  
  result <- normalize_arxiv_records(data)
  
  expect_true("articles" %in% names(result))
  expect_true("authors" %in% names(result))
  expect_true("categories" %in% names(result))
  expect_true("security_categories" %in% names(result))
  expect_true("category_confidence" %in% names(result$articles))
  expect_gt(nrow(result$security_categories), 0)
})

test_that("normalize_arxiv_records creates correct authors table", {
  data <- get_sample_arxiv_data()
  
  result <- normalize_arxiv_records(data)
  
  expect_true("arxiv_id" %in% names(result$authors))
  expect_true("author_name" %in% names(result$authors))
  expect_true("author_order" %in% names(result$authors))
  expect_true(all(!is.na(result$authors$author_name)))
  expect_true(all(result$authors$author_order >= 1))
})

test_that("normalize_arxiv_records creates correct categories table", {
  data <- get_sample_arxiv_data()
  
  result <- normalize_arxiv_records(data)
  
  expect_true("arxiv_id" %in% names(result$categories))
  expect_true("category_term" %in% names(result$categories))
  expect_true(all(!is.na(result$categories$category_term)))
})

test_that("normalize_arxiv_records handles duplicate arxiv_ids", {
  data <- get_sample_arxiv_data()
  data_dup <- rbind(data, data[1, ])
  
  result <- normalize_arxiv_records(data_dup)
  
  expect_equal(nrow(result$articles), nrow(data))
})

test_that("save_to_parquet creates directory if needed", {
  tables <- get_normalized_tables_primary()
  temp_dir <- file.path(tempdir(), "test_parquet")
  
  result <- save_to_parquet(tables, dir = temp_dir)
  
  expect_true(result)
  expect_true(dir.exists(temp_dir))
  expect_true(file.exists(file.path(temp_dir, "articles.parquet")))
  expect_true(file.exists(file.path(temp_dir, "authors.parquet")))
  expect_true(file.exists(file.path(temp_dir, "categories.parquet")))
  
  unlink(temp_dir, recursive = TRUE)
})

test_that("save_to_parquet saves all tables correctly", {
  tables <- get_normalized_tables_primary()
  temp_dir <- file.path(tempdir(), "test_parquet2")
  
  save_to_parquet(tables, dir = temp_dir)
  
  articles <- arrow::read_parquet(file.path(temp_dir, "articles.parquet"))
  authors <- arrow::read_parquet(file.path(temp_dir, "authors.parquet"))
  categories <- arrow::read_parquet(file.path(temp_dir, "categories.parquet"))
  
  expect_equal(nrow(articles), nrow(tables$articles))
  expect_equal(nrow(authors), nrow(tables$authors))
  expect_equal(nrow(categories), nrow(tables$categories))
  
  unlink(temp_dir, recursive = TRUE)
})

test_that("init_duckdb_store creates database and tables", {
  tables <- get_normalized_tables_primary()
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb_store(tables, db_path = temp_db)
  
  expect_s4_class(con, "duckdb_connection")
  
  tables_in_db <- DBI::dbListTables(con)
  expect_true("articles" %in% tables_in_db)
  expect_true("authors" %in% tables_in_db)
  expect_true("categories" %in% tables_in_db)
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("init_duckdb_store creates view", {
  tables <- get_normalized_tables_primary()
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb_store(tables, db_path = temp_db)
  
  tables_and_views <- DBI::dbListTables(con)
  expect_true("v_article_full" %in% tables_and_views)
  
  view_data <- DBI::dbGetQuery(con, "SELECT * FROM v_article_full LIMIT 1")
  expect_gt(nrow(view_data), 0)
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("query_articles retrieves data correctly", {
  tables <- get_normalized_tables_primary()
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb_store(tables, db_path = temp_db)
  
  result <- query_articles(con)
  
  expect_s3_class(result, "tbl_df")
  expect_gt(nrow(result), 0)
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("query_articles filters by date range", {
  tables <- get_normalized_tables_primary()
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb_store(tables, db_path = temp_db)
  
  start_date <- "2024-12-10"
  result <- query_articles(con, start = start_date)
  
  expect_s3_class(result, "tbl_df")
  expect_true(all(result$published_date >= as.POSIXct(start_date, tz = "UTC")))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("query_articles filters by category", {
  tables <- get_normalized_tables_primary()
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb_store(tables, db_path = temp_db)
  
  result <- query_articles(con, category_term = "cs.CR")
  
  expect_s3_class(result, "tbl_df")
  expect_true(all(result$category_term == "cs.CR"))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("e2e_collect_and_store executes full pipeline", {
  skip_if_not_installed("mockery")
  xml_content <- get_sample_arxiv_xml()
  mock_response <- mock_http_response(xml_content)
  
  mockery::stub(
    e2e_collect_and_store,
    "fetch_arxiv_data",
    function(...) get_sample_arxiv_data()
  )
  
  temp_dir <- file.path(tempdir(), "test_e2e")
  
  result <- e2e_collect_and_store(
    categories = "cs.CR",
    max_results = 10,
    out = temp_dir,
    strict_mode = FALSE,
    categorize = TRUE,
    category_mode = "primary",
    use_duckdb = FALSE,
    verbose = FALSE
  )
  
  expect_type(result, "list")
  expect_true("articles" %in% names(result))
  expect_true(file.exists(file.path(temp_dir, "articles.parquet")))
  
  unlink(temp_dir, recursive = TRUE)
})

test_that("e2e_collect_and_store works with duckdb option", {
  skip_if_not_installed("mockery")
  mockery::stub(
    e2e_collect_and_store,
    "fetch_arxiv_data",
    function(...) get_sample_arxiv_data()
  )
  
  temp_dir <- file.path(tempdir(), "test_e2e_db")
  temp_db <- file.path(temp_dir, "test.duckdb")
  
  result <- e2e_collect_and_store(
    categories = "cs.CR",
    max_results = 10,
    out = temp_dir,
    strict_mode = FALSE,
    categorize = TRUE,
    category_mode = "primary",
    use_duckdb = TRUE,
    duckdb_path = temp_db,
    verbose = FALSE
  )
  
  expect_true(file.exists(temp_db))
  
  unlink(temp_dir, recursive = TRUE)
})
