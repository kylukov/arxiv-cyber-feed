#' Run full collection and storage pipeline
#' @export
run_collection_pipeline <- function(categorize = TRUE, category_mode = c("primary", "multi")) {
  raw <- fetch_arxiv_data(categories = c("cs.CR","cs.NI"), max_results = 200)
  filtered <- filter_cybersecurity(raw, strict_mode = TRUE)
  
  # Apply categorization if requested
  if (categorize && nrow(filtered) > 0) {
    category_mode <- match.arg(category_mode)
    filtered <- categorize_articles(filtered, mode = category_mode, verbose = TRUE)
  }
  
  tables <- normalize_arxiv_records(filtered)
  save_to_parquet(tables, dir = "data-raw")
  init_duckdb_store(tables, db_path = "inst/data/arxiv.duckdb")
}
