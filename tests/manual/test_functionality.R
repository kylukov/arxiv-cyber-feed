#!/usr/bin/env Rscript
# Тестовый скрипт для проверки функционала arxiv-cyber-feed

# Загрузка всех модулей
source("/Users/peter/Documents/arxiv-cyber-feed/R/collect_data.R")
source("/Users/peter/Documents/arxiv-cyber-feed/R/storage_utils.R")
source("/Users/peter/Documents/arxiv-cyber-feed/R/analysis_utils.R")

cat("=== ТЕСТ 1: Сбор данных из arXiv API ===\n")
test_data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 15,
  verbose = TRUE
)
cat("Получено записей:", nrow(test_data), "\n")
cat("Колонки:", paste(names(test_data), collapse = ", "), "\n\n")

if (nrow(test_data) > 0) {
  cat("Пример записи:\n")
  print(test_data[1, c("arxiv_id", "title")])
  cat("\n")
}

cat("=== ТЕСТ 2: Фильтрация по кибербезопасности ===\n")
filtered_data <- filter_cybersecurity(test_data, strict_mode = FALSE)
cat("Релевантных статей:", nrow(filtered_data), "\n\n")

if (nrow(filtered_data) > 0) {
  cat("=== ТЕСТ 3: Категоризация статей (primary mode) ===\n")
  categorized_primary <- categorize_articles(
    filtered_data, 
    mode = "primary",
    verbose = TRUE
  )
  cat("\n")
  
  cat("=== ТЕСТ 4: Категоризация статей (multi mode) ===\n")
  categorized_multi <- categorize_articles(
    filtered_data,
    mode = "multi",
    min_score = 1,
    verbose = TRUE
  )
  cat("\n")
  
  cat("=== ТЕСТ 5: Нормализация данных ===\n")
  normalized <- normalize_arxiv_records(categorized_primary)
  cat("Таблицы после нормализации:\n")
  cat("  - articles:", nrow(normalized$articles), "записей\n")
  cat("  - authors:", nrow(normalized$authors), "записей\n")
  cat("  - categories:", nrow(normalized$categories), "записей\n")
  if ("security_categories" %in% names(normalized)) {
    cat("  - security_categories:", nrow(normalized$security_categories), "записей\n")
  }
  cat("\n")
  
  cat("=== ТЕСТ 6: Сохранение в Parquet ===\n")
  test_dir <- "test-output"
  save_result <- save_to_parquet(normalized, dir = test_dir)
  if (save_result) {
    cat("✓ Файлы Parquet успешно сохранены в:", test_dir, "\n")
    cat("Файлы:", paste(list.files(test_dir, pattern = "\\.parquet$"), collapse = ", "), "\n\n")
  }
  
  cat("=== ТЕСТ 7: End-to-end pipeline ===\n")
  e2e_result <- e2e_collect_and_store(
    categories = c("cs.CR", "cs.NI"),
    max_results = 20,
    out = "test-output-e2e",
    strict_mode = TRUE,
    categorize = TRUE,
    category_mode = "primary",
    use_duckdb = FALSE,
    verbose = TRUE
  )
  cat("\nE2E pipeline завершен\n")
  
  cat("=== ТЕСТ 8: Статистика категорий ===\n")
  stats_primary <- get_category_stats(categorized_primary, mode = "primary")
  print(stats_primary)
  cat("\n")
  
  cat("=== ВСЕ ТЕСТЫ ПРОЙДЕНЫ ===\n")
  
} else {
  cat("⚠ Недостаточно данных для продолжения тестов\n")
}
