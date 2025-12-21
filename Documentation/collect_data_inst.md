---
title: "instruction"
format: html
editor: 
  markdown: 
    wrap: 72
---

R-скрипт для сбора данных научных публикаций из arXiv API с фокусом на
кибербезопасность. Файл реализует ETL-процесс (Extract, Transform,
Load).

## Назначение

Извлечение данных из arXiv API Фильтрация публикаций по теме
кибербезопасности Сохранение данных для дальнейшего анализа

## Что собирается

### Для каждой публикации извлекаются:

1.arxiv_id - уникальный идентификатор

2.title - название статьи

3.authors-список авторов

4.abstract - аннотация

5.categories - категории arXiv

6.published_date - дата публикации

7.doi -цифровой идентификатор

8.collection_date - дата сбора данных

## Как проверить файл

### 1. Загрузите файл

```         
source("collect_data.R")
```

### 2. Проверьте сбор данных

```         
data <- fetch_arxiv_data(categories = "cs.CR", max_results = 5, verbose = TRUE)

```

### 3. Посмотрите результат

```         
glimpse(data)

```
