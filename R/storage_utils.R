#' Normalize arXiv records to relational schema
normalize_arxiv_records <- function(df) {
  if (is.null(df) || nrow(df) == 0) {
    warning("Нет данных для нормализации")
    return(list(
      articles = tibble::tibble(),
      authors = tibble::tibble(),
      categories = tibble::tibble(),
      security_categories = tibble::tibble()
    ))
  }
  
  # Check if security categorization columns exist
  has_security_category <- "security_category" %in% names(df)
  has_security_categories <- "security_categories" %in% names(df)
  has_confidence <- "category_confidence" %in% names(df)
  
  articles_base <- df %>%
    dplyr::transmute(
      arxiv_id = as.character(arxiv_id),
      title = as.character(title),
      abstract = as.character(abstract),
      published_date = as.POSIXct(published_date, tz = "UTC"),
      doi = ifelse(is.na(doi), NA_character_, as.character(doi)),
      collection_date = as.POSIXct(collection_date, tz = "UTC")
    )
  
  # Add security categorization if present
  if (has_security_category) {
    articles_base <- articles_base %>%
      dplyr::mutate(
        security_category = as.character(df$security_category),
        category_confidence = if (has_confidence) as.numeric(df$category_confidence) else NA_real_
      )
  } else if (has_security_categories) {
    articles_base <- articles_base %>%
      dplyr::mutate(
        category_confidence = if (has_confidence) as.numeric(df$category_confidence) else NA_real_
      )
  }
  
  articles <- articles_base %>%
    dplyr::distinct(arxiv_id, .keep_all = TRUE)
  
  authors <- df %>%
    dplyr::select(arxiv_id, authors) %>%
    tidyr::unnest_longer(authors, values_to = "author_name") %>%
    dplyr::group_by(arxiv_id) %>%
    dplyr::mutate(author_order = dplyr::row_number()) %>%
    dplyr::ungroup() %>%
    dplyr::filter(!is.na(author_name))
  
  categories <- df %>%
    dplyr::select(arxiv_id, categories) %>%
    tidyr::unnest_longer(categories, values_to = "category_term") %>%
    dplyr::filter(!is.na(category_term))
  
  # Extract security categories if multi-category mode was used
  security_categories <- tibble::tibble()
  if (has_security_categories) {
    security_categories <- df %>%
      dplyr::select(arxiv_id, security_categories) %>%
      tidyr::unnest_longer(security_categories, values_to = "security_category_term") %>%
      dplyr::filter(!is.na(security_category_term))
  }
  
  result <- list(
    articles = articles,
    authors = authors,
    categories = categories
  )
  
  if (nrow(security_categories) > 0) {
    result$security_categories <- security_categories
  }
  
  return(result)
}

#' Save normalized tables to Parquet
save_to_parquet <- function(tables, dir = "data-raw") {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  arrow::write_parquet(tables$articles, file.path(dir, "articles.parquet"))
  arrow::write_parquet(tables$authors, file.path(dir, "authors.parquet"))
  arrow::write_parquet(tables$categories, file.path(dir, "categories.parquet"))
  if ("security_categories" %in% names(tables) && nrow(tables$security_categories) > 0) {
    arrow::write_parquet(tables$security_categories, file.path(dir, "security_categories.parquet"))
  }
  message("Parquet сохранён в: ", normalizePath(dir))
  TRUE
}

#' Initialize DuckDB and write tables
init_duckdb_store <- function(tables, db_path = "inst/data/arxiv.duckdb") {
  dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)
  con <- DBI::dbConnect(duckdb::duckdb(db_path, read_only = FALSE))
  DBI::dbWriteTable(con, "articles", tables$articles, overwrite = TRUE)
  DBI::dbWriteTable(con, "authors", tables$authors, overwrite = TRUE)
  DBI::dbWriteTable(con, "categories", tables$categories, overwrite = TRUE)
  if ("security_categories" %in% names(tables) && nrow(tables$security_categories) > 0) {
    DBI::dbWriteTable(con, "security_categories", tables$security_categories, overwrite = TRUE)
  }
  
  # Build view SQL dynamically
  view_sql <- "CREATE OR REPLACE VIEW v_article_full AS
    SELECT a.*, c.category_term, au.author_name, au.author_order"
  
  if ("security_categories" %in% names(tables) && nrow(tables$security_categories) > 0) {
    view_sql <- paste0(view_sql, ", sc.security_category_term")
  }
  
  view_sql <- paste0(view_sql, "
    FROM articles a
    LEFT JOIN categories c USING(arxiv_id)
    LEFT JOIN authors au USING(arxiv_id)")
  
  if ("security_categories" %in% names(tables) && nrow(tables$security_categories) > 0) {
    view_sql <- paste0(view_sql, "
    LEFT JOIN security_categories sc USING(arxiv_id)")
  }
  
  DBI::dbExecute(con, view_sql)
  message("DuckDB инициализирован: ", normalizePath(db_path))
  invisible(con)
}

#' Query helper
query_articles <- function(con, start = NULL, end = NULL, category_term = NULL) {
  clauses <- c()
  params <- list()
  if (!is.null(start)) { clauses <- c(clauses, "published_date >= ?"); params <- c(params, start) }
  if (!is.null(end))   { clauses <- c(clauses, "published_date <= ?"); params <- c(params, end) }
  if (!is.null(category_term)) { clauses <- c(clauses, "category_term = ?"); params <- c(params, category_term) }
  where_sql <- if (length(clauses)) paste("WHERE", paste(clauses, collapse = " AND ")) else ""
  sql <- paste("SELECT * FROM v_article_full", where_sql, "ORDER BY published_date DESC")
  DBI::dbGetQuery(con, sql, params = params) |> tibble::as_tibble()
}

#' End-to-end pipeline
e2e_collect_and_store <- function(categories = c("cs.CR","cs.NI"), 
                                  max_results = 200,
                                  out = "data-raw",
                                  strict_mode = TRUE,
                                  categorize = TRUE,
                                  category_mode = c("primary", "multi"),
                                  use_duckdb = FALSE,
                                  duckdb_path = "inst/data/arxiv.duckdb",
                                  verbose = TRUE) {
  raw <- fetch_arxiv_data(categories = categories, max_results = max_results, verbose = verbose)
  filtered <- filter_cybersecurity(raw, strict_mode = strict_mode)
  
  # Apply categorization if requested
  if (categorize && nrow(filtered) > 0) {
    if (verbose) message("Применение категоризации статей...")
    category_mode <- match.arg(category_mode)
    filtered <- categorize_articles(filtered, mode = category_mode, verbose = verbose)
  }
  
  tables <- normalize_arxiv_records(filtered)
  save_to_parquet(tables, dir = out)
  if (use_duckdb) init_duckdb_store(tables, db_path = duckdb_path)
  invisible(tables)
}
