#!/usr/bin/env Rscript
# Детальный тест категоризации статей

source("R/collect_data.R")
source("R/analysis_utils.R")
source("R/storage_utils.R")

cat("=== ТЕСТ КАТЕГОРИЗАЦИИ СТАТЕЙ ===\n\n")

# 1. Получаем данные
cat("1. Сбор данных из arXiv...\n")
raw_data <- fetch_arxiv_data(
  categories = c("cs.CR", "cs.NI"),
  max_results = 30,
  verbose = FALSE
)
cat("Получено статей:", nrow(raw_data), "\n\n")

# 2. Фильтрация
cat("2. Фильтрация по кибербезопасности...\n")
filtered_data <- filter_cybersecurity(raw_data, strict_mode = FALSE)
cat("Релевантных статей:", nrow(filtered_data), "\n\n")

if (nrow(filtered_data) == 0) {
  stop("Нет данных для категоризации")
}

# 3. Категоризация в режиме PRIMARY
cat("3. КАТЕГОРИЗАЦИЯ - РЕЖИМ PRIMARY\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")
categorized_primary <- categorize_articles(
  filtered_data,
  mode = "primary",
  verbose = TRUE
)
cat("\n")

# Детальный анализ primary mode
cat("Детальный анализ (primary mode):\n")
for (i in 1:min(5, nrow(categorized_primary))) {
  cat("\n--- Статья", i, "---\n")
  cat("ID:", categorized_primary$arxiv_id[i], "\n")
  cat("Заголовок:", substr(categorized_primary$title[i], 1, 70), "...\n")
  cat("Категория:", categorized_primary$security_category[i], "\n")
  cat("Уверенность:", categorized_primary$category_confidence[i], "\n")
}

# 4. Категоризация в режиме MULTI
cat("\n\n4. КАТЕГОРИЗАЦИЯ - РЕЖИМ MULTI\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")
categorized_multi <- categorize_articles(
  filtered_data,
  mode = "multi",
  min_score = 1,
  verbose = TRUE
)
cat("\n")

# Детальный анализ multi mode
cat("Детальный анализ (multi mode):\n")
for (i in 1:min(5, nrow(categorized_multi))) {
  cat("\n--- Статья", i, "---\n")
  cat("ID:", categorized_multi$arxiv_id[i], "\n")
  cat("Заголовок:", substr(categorized_multi$title[i], 1, 70), "...\n")
  cat("Категории:", paste(categorized_multi$security_categories[[i]], collapse = ", "), "\n")
  cat("Уверенность:", categorized_multi$category_confidence[i], "\n")
}

# 5. Проверка структуры данных
cat("\n\n5. ПРОВЕРКА СТРУКТУРЫ ДАННЫХ\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")
cat("\nКолонки в primary mode:\n")
print(names(categorized_primary))
cat("\nКолонки в multi mode:\n")
print(names(categorized_multi))

cat("\n\nТипы данных (primary):\n")
str(categorized_primary %>% select(arxiv_id, security_category, category_confidence))

cat("\n\nТипы данных (multi):\n")
str(categorized_multi %>% select(arxiv_id, security_categories, category_confidence))

# 6. Статистика категорий
cat("\n\n6. СТАТИСТИКА КАТЕГОРИЙ\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

cat("\nPrimary mode:\n")
stats_primary <- get_category_stats(categorized_primary, mode = "primary")
print(stats_primary)

cat("\n\nMulti mode:\n")
stats_multi <- get_category_stats(categorized_multi, mode = "multi")
print(stats_multi)

# 7. ИНТЕГРАЦИЯ С ОСТАЛЬНЫМ КОДОМ
cat("\n\n7. ИНТЕГРАЦИЯ С STORAGE_UTILS\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

# 7.1 Нормализация primary mode
cat("\n7.1. Нормализация данных (primary mode)...\n")
normalized_primary <- normalize_arxiv_records(categorized_primary)
cat("Таблицы созданы:\n")
cat("  - articles:", nrow(normalized_primary$articles), "записей\n")
cat("  - authors:", nrow(normalized_primary$authors), "записей\n")
cat("  - categories:", nrow(normalized_primary$categories), "записей\n")

# Проверяем наличие security_category в articles
if ("security_category" %in% names(normalized_primary$articles)) {
  cat("  ✓ security_category присутствует в таблице articles\n")
  cat("  Пример распределения:\n")
  print(table(normalized_primary$articles$security_category))
} else {
  cat("  ✗ security_category отсутствует в таблице articles\n")
}

# 7.2 Нормализация multi mode
cat("\n7.2. Нормализация данных (multi mode)...\n")
normalized_multi <- normalize_arxiv_records(categorized_multi)
cat("Таблицы созданы:\n")
cat("  - articles:", nrow(normalized_multi$articles), "записей\n")
cat("  - authors:", nrow(normalized_multi$authors), "записей\n")
cat("  - categories:", nrow(normalized_multi$categories), "записей\n")

if ("security_categories" %in% names(normalized_multi)) {
  cat("  - security_categories:", nrow(normalized_multi$security_categories), "записей\n")
  cat("  ✓ security_categories таблица создана\n")
  cat("  Пример содержания:\n")
  print(head(normalized_multi$security_categories, 10))
} else {
  cat("  ✗ security_categories таблица не создана\n")
}

# 7.3 Сохранение в Parquet
cat("\n7.3. Сохранение в Parquet...\n")
save_to_parquet(normalized_primary, dir = "test-categorization-primary")
save_to_parquet(normalized_multi, dir = "test-categorization-multi")

# 8. END-TO-END с категоризацией
cat("\n\n8. END-TO-END PIPELINE С КАТЕГОРИЗАЦИЕЙ\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

cat("\n8.1. E2E с primary mode...\n")
e2e_primary <- e2e_collect_and_store(
  categories = c("cs.CR"),
  max_results = 20,
  out = "test-e2e-categorization-primary",
  strict_mode = TRUE,
  categorize = TRUE,
  category_mode = "primary",
  use_duckdb = FALSE,
  verbose = FALSE
)

cat("\n8.2. E2E с multi mode...\n")
e2e_multi <- e2e_collect_and_store(
  categories = c("cs.CR"),
  max_results = 20,
  out = "test-e2e-categorization-multi",
  strict_mode = TRUE,
  categorize = TRUE,
  category_mode = "multi",
  use_duckdb = FALSE,
  verbose = FALSE
)

cat("\n8.3. Проверка результатов E2E:\n")
cat("  Primary mode - таблицы:\n")
cat("    articles:", nrow(e2e_primary$articles), "\n")
if ("security_category" %in% names(e2e_primary$articles)) {
  cat("    ✓ security_category в articles\n")
}

cat("\n  Multi mode - таблицы:\n")
cat("    articles:", nrow(e2e_multi$articles), "\n")
if ("security_categories" %in% names(e2e_multi)) {
  cat("    ✓ security_categories создана:", nrow(e2e_multi$security_categories), "записей\n")
}

# 9. Проверка крайних случаев
cat("\n\n9. ТЕСТ КРАЙНИХ СЛУЧАЕВ\n")
cat("=" %>% rep(50) %>% paste(collapse=""), "\n")

# Пустые данные
cat("\n9.1. Пустые данные...\n")
empty_result <- categorize_articles(
  data.frame(),
  mode = "primary",
  verbose = FALSE
)
cat("  Результат:", if(nrow(empty_result) == 0) "✓ Корректно" else "✗ Ошибка", "\n")

# Данные без title/abstract
cat("\n9.2. Проверка обязательных колонок...\n")
test_missing <- tryCatch({
  categorize_articles(
    data.frame(arxiv_id = "test"),
    mode = "primary",
    verbose = FALSE
  )
}, error = function(e) {
  cat("  ✓ Ошибка поймана:", e$message, "\n")
  NULL
})

# Разные min_score в multi mode
cat("\n9.3. Разные пороги (min_score) в multi mode...\n")
for (score in c(1, 2, 3)) {
  result <- categorize_articles(
    filtered_data,
    mode = "multi",
    min_score = score,
    verbose = FALSE
  )
  total_cats <- sum(sapply(result$security_categories, length))
  cat("  min_score =", score, "→ всего категорий:", total_cats, "\n")
}

cat("\n\n=== ВСЕ ТЕСТЫ КАТЕГОРИЗАЦИИ ЗАВЕРШЕНЫ ===\n")
