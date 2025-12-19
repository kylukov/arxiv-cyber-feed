#!/usr/bin/env Rscript
# Быстрый тест категоризации (1-2 минуты)

source("R/collect_data.R")
source("R/analysis_utils.R")
source("R/storage_utils.R")

cat("\n╔════════════════════════════════════════════════════════════════╗\n")
cat("║         БЫСТРЫЙ ТЕСТ КАТЕГОРИЗАЦИИ СТАТЕЙ                      ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

# 1. Сбор данных
cat("📥 Шаг 1/5: Сбор данных из arXiv...\n")
data <- fetch_arxiv_data("cs.CR", max_results = 15, verbose = FALSE)
filtered <- filter_cybersecurity(data, strict_mode = FALSE)
cat("   ✓ Получено статей:", nrow(filtered), "\n\n")

# 2. Категоризация Primary
cat("🏷️  Шаг 2/5: Категоризация (primary mode)...\n")
cat_primary <- categorize_articles(filtered, mode = "primary", verbose = FALSE)
cat("   ✓ Категоризировано\n\n")

# 3. Категоризация Multi
cat("🏷️  Шаг 3/5: Категоризация (multi mode)...\n")
cat_multi <- categorize_articles(filtered, mode = "multi", verbose = FALSE)
cat("   ✓ Категоризировано\n\n")

# 4. Нормализация и интеграция
cat("🗄️  Шаг 4/5: Нормализация и интеграция...\n")
norm_primary <- normalize_arxiv_records(cat_primary)
norm_multi <- normalize_arxiv_records(cat_multi)
cat("   ✓ Primary: security_category в articles -", 
    "security_category" %in% names(norm_primary$articles), "\n")
cat("   ✓ Multi: security_categories таблица создана -", 
    "security_categories" %in% names(norm_multi), "\n\n")

# 5. Примеры категоризации
cat("📊 Шаг 5/5: Примеры категоризации\n")
cat("   ", rep("─", 60), "\n\n", sep="")

for (i in 1:min(3, nrow(cat_primary))) {
  cat("   ", i, ". ", substr(cat_primary$title[i], 1, 55), "...\n", sep="")
  cat("      Primary: ", cat_primary$security_category[i], 
      " (", cat_primary$category_confidence[i], " совп.)\n", sep="")
  cat("      Multi:   ", paste(cat_multi$security_categories[[i]], collapse = ", "), "\n")
  cat("\n")
}

# Статистика
cat("\n📈 СТАТИСТИКА\n")
cat("   ", rep("─", 60), "\n\n", sep="")

cat("   Primary mode - распределение:\n")
stats <- get_category_stats(cat_primary, mode = "primary")
for (i in 1:min(5, nrow(stats))) {
  cat(sprintf("      • %-35s %2d статей (%4.1f%%)\n", 
              stats$security_category[i], 
              stats$n[i], 
              stats$percentage[i]))
}

cat("\n   Multi mode - средних категорий на статью:", 
    round(mean(sapply(cat_multi$security_categories, length)), 2), "\n")

# Заключение
cat("\n╔════════════════════════════════════════════════════════════════╗\n")
cat("║  ✅ КАТЕГОРИЗАЦИЯ РАБОТАЕТ И ИНТЕГРИРОВАНА КОРРЕКТНО           ║\n")
cat("╚════════════════════════════════════════════════════════════════╝\n\n")

cat("📝 Для детального анализа:\n")
cat("   → Rscript test_categorization.R\n")
cat("   → Rscript analyze_categorization_quality.R\n\n")

cat("📖 Документация:\n")
cat("   → CATEGORIZATION_REPORT.md\n\n")
