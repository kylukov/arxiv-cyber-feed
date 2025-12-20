# Dockerfile архитектура и конфигурация – анализ и инструкция

## Общее описание

`Dockerfile` в проекте использует **multi-stage build** для создания оптимизированного Docker образа. Это позволяет уменьшить размер финального образа, отбросив зависимости для сборки, которые не нужны в runtime.

**Структура:**
- **Stage 1 (Builder)** — `rocker/r-ver:4.4.0` — сборка R пакета и установка зависимостей
- **Stage 2 (Runtime)** — `rocker/r-ver:4.4.0` — финальный образ с установленным пакетом

---

## Архитектура Multi-Stage Build

### Зачем использовать Multi-Stage?

```
Stage 1 (Builder) ~ 2.5-3GB
├── система разработки
├── компилятор (g++)
├── исходные коды
├── pak и roxygen2 (только для сборки)
└── дополнительные утилиты для сборки

     ↓ копируется только готовый пакет ↓

Stage 2 (Runtime) ~ 1.2-1.5GB
├── R базовая система
└── установленный пакет + runtime зависимости
```

**Экономия:** Builder образ занимает 2.5-3GB, но в финальном образе остается только Runtime (1.2-1.5GB).

---

## Stage 1: Builder — Подробный разбор

### Шаг 1: Выбор базового образа
```dockerfile
FROM rocker/r-ver:4.4.0 AS builder
```

- **rocker/r-ver:4.4.0** — официальный R образ версии 4.4.0 на Debian
- **AS builder** — именование этапа для ссылки во втором stage

### Шаг 2: Установка системных зависимостей (кэширование)
```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    git \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*
```

**Компоненты:**
| Пакет | Зачем |
|-------|-------|
| `libcurl4-openssl-dev` | Для пакета `httr` (HTTP запросы в arXiv API) |
| `libssl-dev` | Для криптографии и HTTPS (зависимость OpenSSL) |
| `libxml2-dev` | Для пакета `xml2` (парсинг XML из arXiv) |
| `git` | Для установки пакетов из GitHub |
| `make` | Для компиляции некоторых пакетов |
| `g++` | Компилятор C++ для пакетов с C++ кодом |

**Оптимизация кэширования:**
```dockerfile
--mount=type=cache,target=/var/cache/apt
--mount=type=cache,target=/var/lib/apt
```
Кэш монтируется, поэтому при повторной сборке `apt-get` скачивает пакеты из кэша, а не с интернета.

**Очистка:**
```dockerfile
&& rm -rf /var/lib/apt/lists/*
```
Удаляет кэш пакетов для уменьшения размера образа.

### Шаг 3: Установка рабочей директории
```dockerfile
WORKDIR /build
```

Все последующие команды выполняются в `/build`.

### Шаг 4: Установка pakа (dependency manager)
```dockerfile
RUN --mount=type=cache,target=/root/.cache/R/pak \
    R -e "
      options(repos = c(CRAN = 'https://cloud.r-project.org'));
      install.packages('pak', Ncpus = 2)
    "
```

**Почему pak?**
- ✅ Быстрая установка зависимостей (параллельная)
- ✅ Поддержка бинарных пакетов (не нужно компилировать)
- ✅ Умная система резолюции конфликтов
- ✅ Кэширование зависимостей

**Параметры:**
- `options(repos = ...)` — указывает CRAN репозиторий
- `install.packages('pak', Ncpus = 2)` — устанавливает pak с 2 потоками

### Шаг 5: Копирование файлов пакета
```dockerfile
COPY DESCRIPTION NAMESPACE ./
COPY R/ ./R/
COPY man/ ./man/
COPY tests/ ./tests/
```

Копирует структуру R пакета в контейнер.

### Шаг 6: Установка всех зависимостей
```dockerfile
RUN --mount=type=cache,target=/root/.cache/R/pak \
    R -e "
      Sys.setenv(
        PAK_BUILD_BINARY = 'false',
        PAK_USE_BUNDLED_LIBRARIES = 'true'
      );
      options(pkgType = 'binary');
      deps <- pak::local_deps(
        '.',
        dependencies = c('Depends', 'Imports', 'Suggests')
      );
      pak::pkg_install(deps\$ref)
    "
```

**Что делает:**
1. Анализирует `DESCRIPTION` и определяет все зависимости
2. Собирает их в `deps`
3. Устанавливает все зависимости параллельно

**Параметры:**
- `PAK_BUILD_BINARY = 'false'` — не пытаться компилировать
- `PAK_USE_BUNDLED_LIBRARIES = 'true'` — использовать встроенные библиотеки
- `dependencies = c('Depends', 'Imports', 'Suggests')` — установить все типы зависимостей

### Шаг 7: Генерация документации
```dockerfile
RUN R -e "
    Sys.setenv(PAK_BUILD_BINARY = 'false');
    options(pkgType = 'binary');
    pak::pkg_install(c('devtools', 'roxygen2'));
    devtools::document()
"
```

**Что делает:**
1. Устанавливает devtools и roxygen2
2. Генерирует документацию из комментариев `#'` в коде R
3. Создает файлы в `man/` директории

### Шаг 8: Сборка и установка пакета
```dockerfile
RUN R CMD build . && \
    R CMD INSTALL *.tar.gz
```

**Процесс:**
1. `R CMD build .` — создает архив пакета (`arxivThreatIntel_0.1.0.tar.gz`)
2. `R CMD INSTALL *.tar.gz` — устанавливает пакет в системную R библиотеку

---

## Stage 2: Runtime — Подробный разбор

### Шаг 1: Базовый образ
```dockerfile
FROM rocker/r-ver:4.4.0
```

Новый чистый образ, в котором будет только runtime окружение.

### Шаг 2: Установка рабочей директории
```dockerfile
WORKDIR /app
```

Приложение работает в `/app`.

### Шаг 3: Копирование установленных пакетов
```dockerfile
COPY --from=builder /usr/local/lib/R/site-library \
                     /usr/local/lib/R/site-library
```

Копирует из builder stage все установленные R пакеты и пакет arxivThreatIntel.

**Путь `/usr/local/lib/R/site-library`:**
- Это стандартная директория в rocker образах
- Содержит все установленные пакеты
- Автоматически найдется при загрузке R

### Шаг 4: Открытие порта
```dockerfile
EXPOSE 3838
```

Объявляет, что приложение слушает порт 3838 (Shiny).

**Примечание:** EXPOSE не открывает порт автоматически, это просто документация. Реальное открытие происходит через `-p` флаг при запуске контейнера.

### Шаг 5: Default команда (ENTRYPOINT)
```dockerfile
CMD ["Rscript", "-e", "library(arxivThreatIntel); run_visual_dashboard(host='0.0.0.0', port=3838)"]
```

**Что делает:**
1. `Rscript` — интерпретатор R в режиме скрипта
2. `-e "R код"` — выполнить R код
3. `library(arxivThreatIntel)` — загрузить пакет
4. `run_visual_dashboard()` — запустить Shiny приложение
5. `host='0.0.0.0'` — слушать на всех интерфейсах (важно для контейнеров!)
6. `port=3838` — порт Shiny

**По умолчанию контейнер запускает dashboard**, но можно переопределить:
```bash
docker run ... R  # вместо dashboard запустится интерактивная R сессия
```

---

## Сборка образа

### Команда сборки
```bash
docker build -t arxiv-threat-intel .
```

**Процесс:**
1. Dockerfile парсится
2. Загружается `rocker/r-ver:4.4.0` базовый образ
3. Выполняется Stage 1 (Builder) полностью
4. Выполняется Stage 2 (Runtime), копируя файлы из Stage 1
5. Образ тегируется как `arxiv-threat-intel:latest`

### Сборка с конкретной версией
```bash
docker build -t arxiv-threat-intel:0.1.0 .
```

### Сборка для GitHub Container Registry
```bash
docker build -t ghcr.io/username/arxiv-threat-intel:latest .
```

---

## Использование образа

### Запуск dashboard
```bash
docker run -p 3838:3838 arxiv-threat-intel
```

- `-p 3838:3838` — маппирует порт контейнера на хост
- Доступно на `http://localhost:3838`

### Интерактивная R сессия
```bash
docker run -it --rm arxiv-threat-intel R
```

- `-it` — интерактивный режим с TTY
- `--rm` — удаляет контейнер после выхода

### Запуск скрипта
```bash
docker run --rm -v $(pwd)/data-raw:/app/data-raw \
  arxiv-threat-intel \
  Rscript -e "library(arxivThreatIntel); ..."
```

### Запуск тестов
```bash
docker run --rm arxiv-threat-intel \
  Rscript -e "testthat::test_dir('tests/testthat')"
```

---

## Docker Compose

Файл `docker-compose.yml` определяет три сервиса:

### Сервис 1: `arxiv-threat-intel` — Главное приложение
```yaml
services:
  arxiv-threat-intel:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: arxiv-threat-intel
    image: ghcr.io/kulikov/arxiv-threat-intel:latest
    ports:
      - "3838:3838"
    volumes:
      - ./data-raw:/app/data-raw
      - ./inst/data:/app/inst/data
      - ./R:/app/R
      - ./tests:/app/tests
    environment:
      - TZ=UTC
```

**Что делает:**
- Собирает образ из Dockerfile
- Маппирует порт 3838
- Монтирует директории для данных и кода
- По умолчанию запускает dashboard

**Команда:**
```bash
docker-compose up arxiv-threat-intel
```

### Сервис 2: `test` — Полные unit-тесты
```yaml
test:
  build:
    context: .
    dockerfile: Dockerfile
  container_name: arxiv-threat-intel-test
  volumes:
    - ./data-raw:/app/data-raw
    - ./inst/data:/app/inst/data
    - ./R:/app/R
    - ./tests:/app/tests
  command: Rscript -e "testthat::test_dir('tests/testthat')"
```

**Запуск:**
```bash
docker-compose up test
```

### Сервис 3: `quick-test` — Быстрые интеграционные тесты
```yaml
quick-test:
  build:
    context: .
    dockerfile: Dockerfile
  container_name: arxiv-threat-intel-quick-test
  volumes:
    - ./data-raw:/app/data-raw
    - ./tests:/app/tests
    - ./R:/app/R
  command: Rscript tests/manual/quick_test_categorization.R
```

**Запуск:**
```bash
docker-compose up quick-test
```

---

## Архитектура образа на диске

```
# Builder stage
builder                            ~ 2.5-3 GB
├── /etc/apt/                       ~ 50 MB
├── /usr/bin/                       ~ 100 MB
├── /usr/local/lib/R/site-library   ~ 2 GB (пакеты R)
└── /root/.cache/R/pak              ~ 300 MB (кэш pak)

# Runtime stage
final                              ~ 1.2-1.5 GB
├── /etc/apt/                       ~ 50 MB
├── /usr/bin/                       ~ 100 MB
└── /usr/local/lib/R/site-library   ~ 1-1.3 GB (только runtime)
```

---

## Переменные окружения

### Установленные в docker-compose
```yaml
environment:
  - TZ=UTC
```

### Полезные переменные для добавления

```dockerfile
# В Dockerfile
ENV R_LIBS_USER=/usr/local/lib/R/site-library
ENV PATH /usr/local/bin:$PATH
ENV SHINY_LOG_LEVEL=normal
```

### При запуске контейнера
```bash
docker run -e TZ=Europe/Moscow \
           -e R_MAX_NUM_DLLS=500 \
           arxiv-threat-intel
```

---

## Применение

Dockerfile используется для:
- **Разработки:** изолированная среда с фиксированными версиями
- **CI/CD:** воспроизводимые тесты и сборки
- **Production:** развертывание приложения в контейнерах
- **Совместной работы:** все разработчики используют одно окружение
- **Экспорта:** распространение как готовый образ без необходимости установки R

---

## Чек-лист для изменения Dockerfile

Если нужно добавить новую зависимость:

- [ ] Добавить в `DESCRIPTION` файл (Imports или Suggests)
- [ ] Если нужна система библиотека — добавить в Stage 1 (`apt-get install`)
- [ ] Пересобрать образ: `docker build -t arxiv-threat-intel .`
- [ ] Протестировать: `docker run -it arxiv-threat-intel R`
- [ ] В R: `library(new_package); new_function()`

Если изменился R код (R/ директория):

- [ ] Отредактировать файл в `R/`
- [ ] Пересобрать: `docker build -t arxiv-threat-intel .`
- [ ] Сборка будет быстрой благодаря кэшированию
- [ ] Протестировать: `docker-compose up quick-test`
