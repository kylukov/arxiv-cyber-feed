# Docker руководство для arxivThreatIntel

## Быстрый старт

### Сборка образа

```bash
docker build -t arxiv-threat-intel .
```

### Использование docker-compose

#### Запуск интерактивной R сессии

```bash
docker-compose up arxiv-threat-intel
```

#### Запуск тестов

```bash
# Полные тесты
docker-compose up test

# Быстрые тесты категоризации
docker-compose up quick-test
```

## Использование образа из GitHub Container Registry

### Pull образа

```bash
docker pull ghcr.io/[your-username]/arxiv-threat-intel:latest
```

### Запуск контейнера

```bash
docker run -it --rm \
  -v $(pwd)/data-raw:/app/data-raw \
  -v $(pwd)/inst/data:/app/inst/data \
  ghcr.io/[your-username]/arxiv-threat-intel:latest
```

## Примеры использования

### Сбор данных из arXiv

```bash
docker run -it --rm \
  -v $(pwd)/data-raw:/app/data-raw \
  ghcr.io/[your-username]/arxiv-threat-intel:latest \
  Rscript -e "
    library(arxivThreatIntel)
    result <- run_collection_pipeline(
      categories = 'cs.CR',
      max_results = 50,
      verbose = TRUE
    )
  "
```

### Интерактивная работа

```bash
docker run -it --rm \
  -v $(pwd)/data-raw:/app/data-raw \
  -v $(pwd)/inst/data:/app/inst/data \
  ghcr.io/[your-username]/arxiv-threat-intel:latest \
  R
```

Внутри R консоли:

```r
library(arxivThreatIntel)

# Сбор данных
data <- fetch_arxiv_data(
  categories = "cs.CR",
  max_results = 50,
  verbose = TRUE
)

# Категоризация
categorized <- categorize_articles(data, mode = "primary", verbose = TRUE)

# Статистика
stats <- get_category_stats(categorized, mode = "primary")
print(stats)
```

### Запуск скриптов

```bash
# Быстрый тест категоризации
docker run --rm \
  -v $(pwd)/tests:/app/tests \
  -v $(pwd)/R:/app/R \
  ghcr.io/[your-username]/arxiv-threat-intel:latest \
  Rscript tests/manual/quick_test_categorization.R

# Полное тестирование функционала
docker run --rm \
  -v $(pwd)/tests:/app/tests \
  -v $(pwd)/R:/app/R \
  -v $(pwd)/data-raw:/app/data-raw \
  ghcr.io/[your-username]/arxiv-threat-intel:latest \
  Rscript tests/manual/test_functionality.R
```

## Публикация на GitHub Container Registry

### Настройка GitHub Actions

1. GitHub Actions уже настроен через файл `.github/workflows/docker-publish.yml`
2. При пуше в `main`/`master` или создании тега образ автоматически публикуется
3. Образ доступен по адресу: `ghcr.io/[your-username]/arxiv-threat-intel`

### Ручная публикация

```bash
# Логин в GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Сборка и тег
docker build -t ghcr.io/[your-username]/arxiv-threat-intel:latest .

# Push образа
docker push ghcr.io/[your-username]/arxiv-threat-intel:latest
```

### Создание релиза с версией

```bash
# Создание тега
git tag v0.1.0
git push origin v0.1.0

# GitHub Actions автоматически создаст образы с тегами:
# - ghcr.io/[your-username]/arxiv-threat-intel:v0.1.0
# - ghcr.io/[your-username]/arxiv-threat-intel:0.1.0
# - ghcr.io/[your-username]/arxiv-threat-intel:0.1
# - ghcr.io/[your-username]/arxiv-threat-intel:0
# - ghcr.io/[your-username]/arxiv-threat-intel:latest
```

## Настройка видимости пакета

### Публичный доступ к образу

1. Перейдите на страницу пакета на GitHub
2. Settings → Danger Zone → Change visibility
3. Выберите "Public"

Или через GitHub CLI:

```bash
gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  /user/packages/container/arxiv-threat-intel/versions/VERSION_ID \
  -f visibility='public'
```

## Разработка с Docker

### Монтирование локального кода

```bash
docker run -it --rm \
  -v $(pwd)/R:/app/R \
  -v $(pwd)/tests:/app/tests \
  -v $(pwd)/data-raw:/app/data-raw \
  ghcr.io/[your-username]/arxiv-threat-intel:latest \
  bash
```

Затем внутри контейнера:

```bash
# Переустановка пакета с локальными изменениями
R -e "devtools::install('.', dependencies=FALSE)"

# Запуск R
R
```

### docker-compose для разработки

```bash
# Запуск с монтированием локального кода
docker-compose up arxiv-threat-intel

# В другом терминале - вход в контейнер
docker exec -it arxiv-threat-intel bash
```

## Структура volumes

- `./data-raw` → `/app/data-raw` - сырые данные и Parquet файлы
- `./inst/data` → `/app/inst/data` - DuckDB базы данных
- `./R` → `/app/R` - исходный код пакета (для разработки)
- `./tests` → `/app/tests` - тесты (для разработки)

## Переменные окружения

```bash
docker run -it --rm \
  -e TZ=Europe/Moscow \
  -e R_MAX_NUM_DLLS=500 \
  ghcr.io/[your-username]/arxiv-threat-intel:latest
```

## Troubleshooting

### Проблемы с правами доступа к volumes

```bash
# Создание директорий с правильными правами
mkdir -p data-raw inst/data
chmod 777 data-raw inst/data
```

### Очистка старых образов

```bash
# Удаление неиспользуемых образов
docker system prune -a

# Удаление конкретного образа
docker rmi ghcr.io/[your-username]/arxiv-threat-intel:latest
```

### Проверка логов

```bash
# docker-compose
docker-compose logs arxiv-threat-intel

# docker
docker logs [container-id]
```

## Размер образа

Образ основан на `rocker/r-ver:4.4.0` (~600MB базовый размер).
Финальный образ с зависимостями: ~1.2-1.5GB.

Для уменьшения размера можно использовать multi-stage build (опционально).
