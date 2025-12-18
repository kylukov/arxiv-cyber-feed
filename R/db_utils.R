#' Initialize DuckDB connection
#'
#' @param db_path path to DuckDB file
#' @return duckdb connection
init_duckdb <- function(db_path = "data/arxiv.duckdb") {
  if (!dir.exists(dirname(db_path))) {
    dir.create(dirname(db_path), recursive = TRUE)
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  return(con)
}

#' Write normalized data to DuckDB
#'
#' @param normalized_data list from normalize_arxiv_data
#' @param con DuckDB connection
write_to_duckdb <- function(normalized_data, con) {
  DBI::dbWriteTable(con, "papers",
                    normalized_data$papers,
                    overwrite = TRUE)

  DBI::dbWriteTable(con, "authors",
                    normalized_data$authors,
                    overwrite = TRUE)

  DBI::dbWriteTable(con, "categories",
                    normalized_data$categories,
                    overwrite = TRUE)
}

#' Read data from DuckDB
#'
#' @param con DuckDB connection
#' @param query SQL query or NULL
#' @return tibble
#' @export
read_from_duckdb <- function(con, query = NULL) {
  if (is.null(query)) {
    query <- "SELECT * FROM papers"
  }

  DBI::dbGetQuery(con, query)
}

#' Close DuckDB connection
#'
#' @param con DuckDB connection
close_duckdb <- function(con) {
  DBI::dbDisconnect(con, shutdown = TRUE)
}