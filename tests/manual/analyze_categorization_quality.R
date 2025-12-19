#!/usr/bin/env Rscript
# Анализ качества категоризации

source("R/collect_data.R")
source("R/analysis_utils.R")

cat("=== АНАЛИЗ КАЧЕСТВА КАТЕГОРИЗАЦИИ ===\n\n")

# Получаем данные
data <- fetch_arxiv_data(categories = "cs.CR", max_results = 25, verbose = FALSE)
filtered <- filter_cybersecurity(data, strict_mode = FALSE)

cat("Получено статей для анализа:", nrow(filtered), "\n\n")

# Категоризация
categorized_primary <- categorize_articles(filtered, mode = "primary", verbose = FALSE)
categorized_multi <- categorize_articles(filtered, mode = "multi", verbose = FALSE)

# Подробный анализ для каждой статьи
cat("=" %>% rep(80) %>% paste(collapse=""), "\n")
cat("ДЕТАЛЬНЫЙ АНАЛИЗ КАТЕГОРИЗАЦИИ\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n\n")

for (i in 1:min(10, nrow(categorized_primary))) {
  cat("\n", rep("─", 80) %>% paste(collapse=""), "\n")
  cat("СТАТЬЯ #", i, "\n")
  cat(rep("─", 80) %>% paste(collapse=""), "\n\n")
  
  cat("arXiv ID:", categorized_primary$arxiv_id[i], "\n\n")
  
  cat("ЗАГОЛОВОК:\n")
  cat(strwrap(categorized_primary$title[i], width = 75, prefix = "  "), sep = "\n")
  cat("\n")
  
  cat("АБСТРАКТ (первые 300 символов):\n")
  abstract_preview <- substr(categorized_primary$abstract[i], 1, 300)
  cat(strwrap(abstract_preview, width = 75, prefix = "  "), sep = "\n")
  cat("  ...\n\n")
  
  cat("КАТЕГОРИЗАЦИЯ:\n")
  cat("  Primary mode:\n")
  cat("    Категория:", categorized_primary$security_category[i], "\n")
  cat("    Уверенность:", categorized_primary$category_confidence[i], "совпадений\n\n")
  
  cat("  Multi mode:\n")
  multi_cats <- categorized_multi$security_categories[[i]]
  cat("    Категории (", length(multi_cats), "):\n", sep = "")
  for (cat_name in multi_cats) {
    cat("      -", cat_name, "\n")
  }
  cat("    Уверенность:", categorized_multi$category_confidence[i], "совпадений\n")
}

# Статистика
cat("\n\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n")
cat("ОБЩАЯ СТАТИСТИКА\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n\n")

cat("PRIMARY MODE - Распределение:\n")
cat(rep("-", 40) %>% paste(collapse=""), "\n")
stats_primary <- get_category_stats(categorized_primary, mode = "primary")
for (i in 1:nrow(stats_primary)) {
  cat(sprintf("  %-40s %3d статей (%5.1f%%)\n", 
              stats_primary$security_category[i], 
              stats_primary$n[i],
              stats_primary$percentage[i]))
}

cat("\n\nMULTI MODE - Распределение:\n")
cat(rep("-", 40) %>% paste(collapse=""), "\n")
stats_multi <- get_category_stats(categorized_multi, mode = "multi")
for (i in 1:nrow(stats_multi)) {
  cat(sprintf("  %-40s %3d упоминаний (%5.1f%%)\n", 
              stats_multi$category[i], 
              stats_multi$n[i],
              stats_multi$percentage[i]))
}

# Анализ уверенности
cat("\n\nАНАЛИЗ УВЕРЕННОСТИ КАТЕГОРИЗАЦИИ:\n")
cat(rep("-", 40) %>% paste(collapse=""), "\n")
cat("Primary mode:\n")
cat("  Средняя уверенность:", round(mean(categorized_primary$category_confidence), 2), "\n")
cat("  Медиана:", median(categorized_primary$category_confidence), "\n")
cat("  Минимум:", min(categorized_primary$category_confidence), "\n")
cat("  Максимум:", max(categorized_primary$category_confidence), "\n")

cat("\nMulti mode:\n")
cat("  Средняя уверенность:", round(mean(categorized_multi$category_confidence), 2), "\n")
cat("  Медиана:", median(categorized_multi$category_confidence), "\n")
cat("  Среднее количество категорий на статью:", 
    round(mean(sapply(categorized_multi$security_categories, length)), 2), "\n")

# Статьи с низкой уверенностью
cat("\n\nСТАТЬИ С НИЗКОЙ УВЕРЕННОСТЬЮ (0-1 совпадения):\n")
cat(rep("-", 40) %>% paste(collapse=""), "\n")
low_conf <- categorized_primary[categorized_primary$category_confidence <= 1, ]
if (nrow(low_conf) > 0) {
  for (i in 1:nrow(low_conf)) {
    cat("\n", i, ". ", low_conf$title[i], "\n", sep = "")
    cat("   Категория:", low_conf$security_category[i], "\n")
    cat("   Уверенность:", low_conf$category_confidence[i], "\n")
  }
} else {
  cat("  Нет статей с низкой уверенностью\n")
}

# Статьи с высокой уверенностью
cat("\n\nСТАТЬИ С ВЫСОКОЙ УВЕРЕННОСТЬЮ (≥5 совпадений):\n")
cat(rep("-", 40) %>% paste(collapse=""), "\n")
high_conf <- categorized_primary[categorized_primary$category_confidence >= 5, ]
if (nrow(high_conf) > 0) {
  for (i in 1:nrow(high_conf)) {
    cat("\n", i, ". ", high_conf$title[i], "\n", sep = "")
    cat("   Категория:", high_conf$security_category[i], "\n")
    cat("   Уверенность:", high_conf$category_confidence[i], "\n")
  }
} else {
  cat("  Нет статей с высокой уверенностью\n")
}

cat("\n\n=== АНАЛИЗ ЗАВЕРШЕН ===\n")
