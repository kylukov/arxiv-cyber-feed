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
