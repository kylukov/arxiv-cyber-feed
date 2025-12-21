test_that("init_duckdb creates database file", {
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb(db_path = temp_db)
  
  expect_s4_class(con, "duckdb_connection")
  expect_true(file.exists(temp_db))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("init_duckdb creates directory if needed", {
  temp_dir <- file.path(tempdir(), "test_db_dir")
  temp_db <- file.path(temp_dir, "test.duckdb")
  
  con <- init_duckdb(db_path = temp_db)
  
  expect_true(dir.exists(temp_dir))
  expect_true(file.exists(temp_db))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_dir, recursive = TRUE)
})

test_that("init_duckdb returns valid connection", {
  temp_db <- tempfile(fileext = ".duckdb")
  
  con <- init_duckdb(db_path = temp_db)
  
  expect_true(DBI::dbIsValid(con))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("write_to_duckdb writes all tables", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  normalized_data <- list(
    papers = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      title = c("Paper 1", "Paper 2"),
      abstract = c("Abstract 1", "Abstract 2")
    ),
    authors = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.12345", "2412.54321"),
      author_name = c("Alice", "Bob", "Charlie"),
      author_order = c(1, 2, 1)
    ),
    categories = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      category_term = c("cs.CR", "cs.AI")
    )
  )
  
  write_to_duckdb(normalized_data, con)
  
  tables <- DBI::dbListTables(con)
  expect_true("papers" %in% tables)
  expect_true("authors" %in% tables)
  expect_true("categories" %in% tables)
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("write_to_duckdb preserves data integrity", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  normalized_data <- list(
    papers = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      title = c("Paper 1", "Paper 2"),
      abstract = c("Abstract 1", "Abstract 2")
    ),
    authors = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.12345", "2412.54321"),
      author_name = c("Alice", "Bob", "Charlie"),
      author_order = c(1, 2, 1)
    ),
    categories = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      category_term = c("cs.CR", "cs.AI")
    )
  )
  
  write_to_duckdb(normalized_data, con)
  
  papers <- DBI::dbGetQuery(con, "SELECT * FROM papers")
  authors <- DBI::dbGetQuery(con, "SELECT * FROM authors")
  categories <- DBI::dbGetQuery(con, "SELECT * FROM categories")
  
  expect_equal(nrow(papers), nrow(normalized_data$papers))
  expect_equal(nrow(authors), nrow(normalized_data$authors))
  expect_equal(nrow(categories), nrow(normalized_data$categories))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("write_to_duckdb overwrites existing tables", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  data1 <- list(
    papers = tibble::tibble(arxiv_id = "1", title = "Test 1", abstract = "Abstract 1"),
    authors = tibble::tibble(arxiv_id = "1", author_name = "Alice", author_order = 1),
    categories = tibble::tibble(arxiv_id = "1", category_term = "cs.CR")
  )
  
  data2 <- list(
    papers = tibble::tibble(arxiv_id = c("2", "3"), title = c("Test 2", "Test 3"), abstract = c("Abstract 2", "Abstract 3")),
    authors = tibble::tibble(arxiv_id = c("2", "3"), author_name = c("Bob", "Charlie"), author_order = c(1, 1)),
    categories = tibble::tibble(arxiv_id = c("2", "3"), category_term = c("cs.AI", "cs.NI"))
  )
  
  write_to_duckdb(data1, con)
  write_to_duckdb(data2, con)
  
  papers <- DBI::dbGetQuery(con, "SELECT * FROM papers")
  expect_equal(nrow(papers), 2)
  expect_false("1" %in% papers$arxiv_id)
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("read_from_duckdb retrieves data with default query", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  normalized_data <- list(
    papers = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      title = c("Paper 1", "Paper 2"),
      abstract = c("Abstract 1", "Abstract 2")
    ),
    authors = tibble::tibble(
      arxiv_id = c("2412.12345"),
      author_name = c("Alice"),
      author_order = c(1)
    ),
    categories = tibble::tibble(
      arxiv_id = c("2412.12345"),
      category_term = c("cs.CR")
    )
  )
  
  write_to_duckdb(normalized_data, con)
  
  result <- read_from_duckdb(con)
  
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("arxiv_id" %in% names(result))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("read_from_duckdb handles custom queries", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  normalized_data <- list(
    papers = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      title = c("Security Paper", "AI Paper"),
      abstract = c("Abstract 1", "Abstract 2")
    ),
    authors = tibble::tibble(
      arxiv_id = c("2412.12345"),
      author_name = c("Alice"),
      author_order = c(1)
    ),
    categories = tibble::tibble(
      arxiv_id = c("2412.12345"),
      category_term = c("cs.CR")
    )
  )
  
  write_to_duckdb(normalized_data, con)
  
  result <- read_from_duckdb(con, query = "SELECT * FROM papers WHERE title LIKE '%Security%'")
  
  expect_equal(nrow(result), 1)
  expect_equal(result$arxiv_id[1], "2412.12345")
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("read_from_duckdb can join tables", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  normalized_data <- list(
    papers = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      title = c("Paper 1", "Paper 2"),
      abstract = c("Abstract 1", "Abstract 2")
    ),
    authors = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.12345", "2412.54321"),
      author_name = c("Alice", "Bob", "Charlie"),
      author_order = c(1, 2, 1)
    ),
    categories = tibble::tibble(
      arxiv_id = c("2412.12345", "2412.54321"),
      category_term = c("cs.CR", "cs.AI")
    )
  )
  
  write_to_duckdb(normalized_data, con)
  
  query <- "SELECT p.arxiv_id, p.title, a.author_name 
            FROM papers p 
            JOIN authors a ON p.arxiv_id = a.arxiv_id"
  result <- read_from_duckdb(con, query = query)
  
  expect_gt(nrow(result), 0)
  expect_true(all(c("arxiv_id", "title", "author_name") %in% names(result)))
  
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(temp_db)
})

test_that("close_duckdb closes connection properly", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  expect_true(DBI::dbIsValid(con))
  
  close_duckdb(con)
  
  expect_false(DBI::dbIsValid(con))
  
  unlink(temp_db)
})

test_that("close_duckdb shuts down database", {
  temp_db <- tempfile(fileext = ".duckdb")
  con <- init_duckdb(db_path = temp_db)
  
  normalized_data <- list(
    papers = tibble::tibble(arxiv_id = "1", title = "Test", abstract = "Abstract"),
    authors = tibble::tibble(arxiv_id = "1", author_name = "Alice", author_order = 1),
    categories = tibble::tibble(arxiv_id = "1", category_term = "cs.CR")
  )
  
  write_to_duckdb(normalized_data, con)
  close_duckdb(con)
  
  con2 <- init_duckdb(db_path = temp_db)
  papers <- DBI::dbGetQuery(con2, "SELECT * FROM papers")
  expect_equal(nrow(papers), 1)
  
  DBI::dbDisconnect(con2, shutdown = TRUE)
  unlink(temp_db)
})
