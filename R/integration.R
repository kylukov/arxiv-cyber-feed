#' Run full collection and storage pipeline
#' @export
run_collection_pipeline <- function() {
  raw <- fetch_arxiv_data(categories = c("cs.CR","cs.NI"), max_results = 200)
  filtered <- filter_cybersecurity(raw, strict_mode = TRUE)
  tables <- normalize_arxiv_records(filtered)
  save_to_parquet(tables, dir = "data-raw")
  init_duckdb_store(tables, db_path = "inst/data/arxiv.duckdb")
}
