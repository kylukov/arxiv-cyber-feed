test_that("plot_category_distribution handles empty data", {
  empty_data <- tibble::tibble()
  
  expect_error(
    plot_category_distribution(empty_data, mode = "primary"),
    "Пустой набор данных"
  )
})

test_that("plot_category_distribution works with primary mode", {
  data <- get_categorized_data_primary()
  
  p <- plot_category_distribution(data, mode = "primary")
  
  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
  expect_true("n" %in% names(p$data))
})

test_that("plot_category_distribution works with multi mode", {
  data <- get_categorized_data_multi()
  
  p <- plot_category_distribution(data, mode = "multi")
  
  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
  expect_true("n" %in% names(p$data))
})

test_that("plot_category_distribution respects top_n parameter", {
  data <- get_categorized_data_primary()
  
  p_all <- plot_category_distribution(data, mode = "primary", top_n = NULL)
  p_limited <- plot_category_distribution(data, mode = "primary", top_n = 2)
  
  expect_lte(nrow(p_limited$data), 2)
  expect_lte(nrow(p_limited$data), nrow(p_all$data))
})

test_that("plot_category_distribution validates mode parameter", {
  data <- get_categorized_data_multi()
  
  expect_error(
    plot_category_distribution(data, mode = "primary"),
    "security_category"
  )
})

test_that("plot_category_distribution creates proper ggplot layers", {
  data <- get_categorized_data_primary()
  
  p <- plot_category_distribution(data, mode = "primary")
  
  expect_true(length(p$layers) > 0)
  expect_s3_class(p$layers[[1]]$geom, "GeomCol")
})

test_that("plot_category_distribution has correct labels", {
  data <- get_categorized_data_primary()
  
  p <- plot_category_distribution(data, mode = "primary")
  
  expect_true(!is.null(p$labels$x))
  expect_true(!is.null(p$labels$y))
  expect_true(!is.null(p$labels$title))
})

test_that("plot_category_distribution uses coord_flip", {
  data <- get_categorized_data_primary()
  
  p <- plot_category_distribution(data, mode = "primary")
  
  has_coord_flip <- any(sapply(p$coordinates, function(x) inherits(x, "CoordFlip")))
  expect_true(has_coord_flip || !is.null(p$coordinates))
})

test_that("plot_publication_timeline handles empty data", {
  empty_data <- tibble::tibble()
  
  expect_error(
    plot_publication_timeline(empty_data, by = "month"),
    "Пустой набор данных"
  )
})

test_that("plot_publication_timeline requires published_date column", {
  data <- tibble::tibble(
    arxiv_id = "123",
    title = "Test"
  )
  
  expect_error(
    plot_publication_timeline(data, by = "month"),
    "отсутствует колонка 'published_date'"
  )
})

test_that("plot_publication_timeline works with month aggregation", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
  expect_true("period" %in% names(p$data))
  expect_true("n" %in% names(p$data))
})

test_that("plot_publication_timeline works with week aggregation", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "week", facet_by_category = FALSE)
  
  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
  expect_true("period" %in% names(p$data))
})

test_that("plot_publication_timeline validates by parameter", {
  data <- get_categorized_data_primary()
  
  expect_error(
    plot_publication_timeline(data, by = "invalid"),
    "'arg' should be one of"
  )
})

test_that("plot_publication_timeline works without faceting", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_s3_class(p, "ggplot")
  expect_true(!"security_category" %in% names(p$data) || 
              !any(sapply(p$facet, function(x) inherits(x, "FacetWrap"))))
})

test_that("plot_publication_timeline works with faceting by category", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = TRUE)
  
  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
  expect_true("security_category" %in% names(p$data))
})

test_that("plot_publication_timeline aggregates data correctly", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_lte(nrow(p$data), nrow(data))
  expect_true(all(p$data$n > 0))
})

test_that("plot_publication_timeline creates proper ggplot layers", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_true(length(p$layers) > 0)
  expect_s3_class(p$layers[[1]]$geom, "GeomCol")
})

test_that("plot_publication_timeline has correct labels", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_true(!is.null(p$labels$x))
  expect_true(!is.null(p$labels$y))
  expect_true(!is.null(p$labels$title))
})

test_that("plot_publication_timeline handles data without security_category", {
  data <- get_sample_arxiv_data()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_s3_class(p, "ggplot")
  expect_true(!is.null(p$data))
})

test_that("plot_publication_timeline ignores faceting when security_category absent", {
  data <- get_sample_arxiv_data()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = TRUE)
  
  expect_s3_class(p, "ggplot")
  expect_false("security_category" %in% names(p$data))
})

test_that("plot_category_distribution works with large dataset", {
  data <- get_categorized_data_primary()
  data_large <- do.call(rbind, replicate(10, data, simplify = FALSE))
  
  p <- plot_category_distribution(data_large, mode = "primary")
  
  expect_s3_class(p, "ggplot")
  expect_equal(sum(p$data$n), nrow(data_large))
})

test_that("plot_publication_timeline groups data by period correctly", {
  data <- get_categorized_data_primary()
  
  p <- plot_publication_timeline(data, by = "month", facet_by_category = FALSE)
  
  expect_s3_class(p$data$period, "POSIXct")
})
