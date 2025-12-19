# Базовый образ с R
FROM rocker/r-ver:4.4.0

# Метаданные
LABEL maintainer="your-email@example.com"
LABEL description="Docker image for arxivThreatIntel R package"

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Установка R зависимостей
RUN R -e "install.packages(c( \
    'dplyr', \
    'tidyr', \
    'tibble', \
    'arrow', \
    'DBI', \
    'duckdb', \
    'httr', \
    'xml2', \
    'stringr', \
    'lubridate', \
    'purrr', \
    'testthat', \
    'roxygen2', \
    'devtools', \
    'remotes' \
    ), repos='https://cloud.r-project.org/')"

# Создание рабочей директории
WORKDIR /app

# Копирование файлов пакета
COPY DESCRIPTION NAMESPACE ./
COPY R/ ./R/
COPY man/ ./man/
COPY tests/ ./tests/
COPY README.md ./

# Создание необходимых директорий
RUN mkdir -p data-raw inst/data

# Установка пакета
RUN R -e "devtools::install('.', dependencies=TRUE, upgrade='never')"

# Команда по умолчанию - запуск R
CMD ["R"]