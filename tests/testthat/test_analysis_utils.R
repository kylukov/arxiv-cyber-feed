test_that("categorize_articles handles empty data", {
  empty_data <- tibble::tibble()
  
  expect_warning(
    result <- categorize_articles(empty_data, verbose = FALSE),
    "Входной набор данных пуст"
  )
  expect_equal(nrow(result), 0)
})

test_that("categorize_articles validates required columns", {
  data <- tibble::tibble(arxiv_id = "123", title = "Test")
  
  expect_error(
    categorize_articles(data, verbose = FALSE),
    "Отсутствуют обязательные колонки"
  )
})

test_that("categorize_articles works in primary mode", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "primary", verbose = FALSE)
  
  expect_s3_class(result, "tbl_df")
  expect_true("security_category" %in% names(result))
  expect_true("category_confidence" %in% names(result))
  expect_equal(nrow(result), nrow(data))
  expect_type(result$security_category, "character")
  expect_type(result$category_confidence, "double")
})

test_that("categorize_articles assigns correct categories in primary mode", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "primary", verbose = FALSE)
  
  expect_true(any(grepl("Криптография", result$security_category)))
  expect_true(any(grepl("Вредоносное ПО", result$security_category) | 
                    grepl("IoT", result$security_category)))
})

test_that("categorize_articles assigns only one category per article in primary mode", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "primary", verbose = FALSE)
  
  expect_equal(length(result$security_category), nrow(result))
  expect_true(all(nchar(result$security_category) > 0))
})

test_that("categorize_articles works in multi mode", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "multi", verbose = FALSE)
  
  expect_s3_class(result, "tbl_df")
  expect_true("security_categories" %in% names(result))
  expect_true("category_confidence" %in% names(result))
  expect_equal(nrow(result), nrow(data))
  expect_type(result$security_categories, "list")
})

test_that("categorize_articles can assign multiple categories in multi mode", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "multi", verbose = FALSE)
  
  categories_lengths <- purrr::map_int(result$security_categories, length)
  expect_true(any(categories_lengths > 1))
  expect_true(all(categories_lengths >= 1))
})

test_that("categorize_articles respects min_score in multi mode", {
  data <- get_sample_arxiv_data()
  
  result_min1 <- categorize_articles(data, mode = "multi", min_score = 1, verbose = FALSE)
  result_min5 <- categorize_articles(data, mode = "multi", min_score = 5, verbose = FALSE)
  
  lengths_min1 <- purrr::map_int(result_min1$security_categories, length)
  lengths_min5 <- purrr::map_int(result_min5$security_categories, length)
  
  expect_true(mean(lengths_min1) >= mean(lengths_min5))
})

test_that("categorize_articles assigns 'Прочее' for unmatched articles in primary mode", {
  data <- get_non_security_data()
  
  result <- categorize_articles(data, mode = "primary", verbose = FALSE)
  
  expect_true(all(result$security_category == "Прочее"))
  expect_true(all(result$category_confidence == 0))
})

test_that("categorize_articles assigns 'Прочее' for unmatched articles in multi mode", {
  data <- get_non_security_data()
  
  result <- categorize_articles(data, mode = "multi", verbose = FALSE)
  
  all_prochee <- purrr::map_lgl(result$security_categories, function(cats) {
    length(cats) == 1 && cats[1] == "Прочее"
  })
  
  expect_true(all(all_prochee))
})

test_that("categorize_articles computes category_confidence correctly", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "primary", verbose = FALSE)
  
  expect_true(all(result$category_confidence >= 0))
  expect_type(result$category_confidence, "double")
})

test_that("categorize_articles does not add internal columns to output", {
  data <- get_sample_arxiv_data()
  
  result <- categorize_articles(data, mode = "primary", verbose = FALSE)
  
  expect_false("search_text" %in% names(result))
  expect_false("category_scores_list" %in% names(result))
  expect_false("max_score" %in% names(result))
  expect_false("primary_category" %in% names(result))
})

test_that(".get_category_patterns returns valid patterns", {
  patterns <- arxivThreatIntel:::.get_category_patterns()
  
  expect_type(patterns, "list")
  expect_true(length(patterns) >= 10)
  expect_true("cryptography" %in% names(patterns))
  expect_true("network_security" %in% names(patterns))
  expect_true("malware_threats" %in% names(patterns))
  
  expect_true(all(purrr::map_lgl(patterns, is.character)))
  expect_true(all(purrr::map_int(patterns, nchar) > 0))
})

test_that(".get_category_patterns contains expected keywords", {
  patterns <- arxivThreatIntel:::.get_category_patterns()
  
  expect_match(patterns$cryptography, "aes|rsa|encryption", ignore.case = TRUE)
  expect_match(patterns$network_security, "firewall|vpn|intrusion", ignore.case = TRUE)
  expect_match(patterns$malware_threats, "malware|ransomware|trojan", ignore.case = TRUE)
})

test_that("get_category_stats works with primary mode data", {
  data <- get_categorized_data_primary()
  
  stats <- get_category_stats(data, mode = "primary")
  
  expect_s3_class(stats, "tbl_df")
  expect_true("security_category" %in% names(stats))
  expect_true("n" %in% names(stats))
  expect_true("percentage" %in% names(stats))
  expect_true("cumulative_pct" %in% names(stats))
  expect_equal(sum(stats$n), nrow(data))
})

test_that("get_category_stats works with multi mode data", {
  data <- get_categorized_data_multi()
  
  stats <- get_category_stats(data, mode = "multi")
  
  expect_s3_class(stats, "tbl_df")
  expect_true("category" %in% names(stats))
  expect_true("n" %in% names(stats))
  expect_true("percentage" %in% names(stats))
  expect_true("cumulative_pct" %in% names(stats))
  expect_gte(sum(stats$n), nrow(data))
})

test_that("get_category_stats validates input for primary mode", {
  data <- get_categorized_data_multi()
  
  expect_error(
    get_category_stats(data, mode = "primary"),
    "Колонка security_category не найдена"
  )
})

test_that("get_category_stats validates input for multi mode", {
  data <- get_categorized_data_primary()
  
  expect_error(
    get_category_stats(data, mode = "multi"),
    "Колонка security_categories не найдена"
  )
})

test_that("get_category_stats calculates percentages correctly", {
  data <- get_categorized_data_primary()
  
  stats <- get_category_stats(data, mode = "primary")
  
  expect_equal(round(sum(stats$percentage), 2), 100.00)
  expect_true(all(stats$percentage > 0))
  expect_true(all(stats$percentage <= 100))
})

test_that("get_category_stats orders categories by count", {
  data <- get_categorized_data_primary()
  
  stats <- get_category_stats(data, mode = "primary")
  
  expect_equal(stats$n, sort(stats$n, decreasing = TRUE))
})

test_that("get_category_stats calculates cumulative percentages correctly", {
  data <- get_categorized_data_primary()
  
  stats <- get_category_stats(data, mode = "primary")
  
  expect_true(all(diff(stats$cumulative_pct) >= 0))
  expect_equal(stats$cumulative_pct[nrow(stats)], 100.00)
})
