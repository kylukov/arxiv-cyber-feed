# Visualization utilities and Shiny dashboard for arxivThreatIntel
#
# Всё, что связано с визуализацией (графики + веб‑интерфейс),
# собрано в этом файле: функции построения графиков и минимальный
# Shiny‑дашборд.

library(dplyr)
library(ggplot2)
library(lubridate)
library(shiny)

#' Построить распределение статей по категориям безопасности
#'
#' @param data Датафрейм, возвращённый `categorize_articles()`
#'   (mode = "primary" или "multi")
#' @param mode Режим категоризации: "primary" или "multi"
#' @param top_n При большом числе категорий можно отобразить только TOP-N
#'
#' @return Объект ggplot2 (его можно вывести через `print()` или в RStudio)
#' @examples
#' \dontrun{
#' stats <- get_category_stats(categorized, mode = "primary")
#' p <- plot_category_distribution(categorized, mode = "primary")
#' print(p)
#' }
plot_category_distribution <- function(data,
                                       mode = c("primary", "multi"),
                                       top_n = NULL) {
  mode <- match.arg(mode)

  if (is.null(data) || nrow(data) == 0) {
    stop("Пустой набор данных: нечего визуализировать")
  }

  stats <- get_category_stats(data, mode = mode)

  # Если нужно ограничить количество категорий
  if (!is.null(top_n) && is.numeric(top_n) && top_n > 0) {
    stats <- stats %>%
      dplyr::arrange(dplyr::desc(n)) %>%
      dplyr::slice(1:min(top_n, n()))
  }

  # Название столбца с категорией зависит от режима
  category_col <- if (mode == "primary") "security_category" else "category"

  # Переводим в фактор с сортировкой по убыванию количества
  stats <- stats %>%
    dplyr::mutate(
      category_factor = factor(.data[[category_col]],
                               levels = stats[[category_col]][order(stats$n)])
    )

  p <- ggplot2::ggplot(stats,
                       ggplot2::aes(x = category_factor, y = n)) +
    ggplot2::geom_col(fill = "#2C7BB6") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      x = "Категория безопасности",
      y = "Количество статей",
      title = "Распределение статей по тематикам безопасности"
    ) +
    ggplot2::theme_minimal(base_size = 12)

  return(p)
}

#' Построить динамику публикаций во времени
#'
#' @param data Датафрейм с колонкой `published_date` (и опционально
#'   `security_category` для фасетирования по тематикам)
#' @param by Период агрегации: "month" или "week"
#' @param facet_by_category Логический флаг: строить ли отдельные графики
#'   по каждой категории (только если есть `security_category`)
#'
#' @return Объект ggplot2
#' @examples
#' \dontrun{
#' p <- plot_publication_timeline(categorized, by = "month",
#'                                facet_by_category = FALSE)
#' print(p)
#' }
plot_publication_timeline <- function(data,
                                      by = c("month", "week"),
                                      facet_by_category = FALSE) {
  by <- match.arg(by)

  if (is.null(data) || nrow(data) == 0) {
    stop("Пустой набор данных: нечего визуализировать")
  }

  if (!"published_date" %in% names(data)) {
    stop("В данных отсутствует колонка 'published_date'")
  }

  # Приводим даты к началу периода
  data_agg <- data %>%
    dplyr::mutate(
      period = dplyr::case_when(
        by == "month" ~ lubridate::floor_date(published_date, "month"),
        by == "week"  ~ lubridate::floor_date(published_date, "week"),
        TRUE ~ published_date
      )
    )

  if (facet_by_category && "security_category" %in% names(data_agg)) {
    data_agg <- data_agg %>%
      dplyr::group_by(period, security_category) %>%
      dplyr::summarise(n = dplyr::n(), .groups = "drop")

    p <- ggplot2::ggplot(data_agg,
                         ggplot2::aes(x = period, y = n)) +
      ggplot2::geom_col(fill = "#2C7BB6") +
      ggplot2::facet_wrap(~ security_category, scales = "free_y") +
      ggplot2::labs(
        x = "Период",
        y = "Количество статей",
        title = "Динамика публикаций по тематикам безопасности"
      ) +
      ggplot2::theme_minimal(base_size = 12)
  } else {
    data_agg <- data_agg %>%
      dplyr::group_by(period) %>%
      dplyr::summarise(n = dplyr::n(), .groups = "drop")

    p <- ggplot2::ggplot(data_agg,
                         ggplot2::aes(x = period, y = n)) +
      ggplot2::geom_col(fill = "#2C7BB6") +
      ggplot2::labs(
        x = "Период",
        y = "Количество статей",
        title = "Динамика публикаций по времени"
      ) +
      ggplot2::theme_minimal(base_size = 12)
  }

  return(p)
}

#' Запустить минимальный Shiny‑дашборд
#'
#' Открывает веб‑страницу с:
#'  - выбором категорий arXiv и параметров сбора,
#'  - графиком распределения статей по тематикам,
#'  - графиком динамики публикаций во времени.
#'
#' @param host Хост для запуска (по умолчанию "0.0.0.0")
#' @param port Порт для запуска (по умолчанию 3838)
#'
#' @return Ничего (блокирует R‑сессию, пока дашборд запущен)
#' @export
run_visual_dashboard <- function(host = "0.0.0.0", port = 3838) {
  ui <- shiny::fluidPage(
    shiny::tags$head(
      shiny::tags$style(shiny::HTML("
        body {
          background-color: #020617;
          color: #e5e7eb;
        }
        .app-container {
          max-width: 1400px;
          margin: 0 auto;
          padding: 20px 10px 40px 10px;
        }
        .app-header-title {
          margin-bottom: 4px;
          font-weight: 600;
          color: #f9fafb;
        }
        .app-header-subtitle {
          color: #9ca3af;
          margin-bottom: 20px;
        }
        .control-panel {
          background: #020617;
          border-radius: 10px;
          box-shadow: 0 1px 4px rgba(15, 23, 42, 0.7);
          padding: 18px 18px 10px 18px;
          border: 1px solid #1e293b;
        }
        .control-panel .shiny-input-container {
          margin-bottom: 12px;
        }
        .control-panel label {
          color: #e5e7eb;
          font-weight: 500;
        }
        .control-panel .form-control,
        .control-panel .selectize-control .selectize-input {
          background-color: #020617 !important;
          color: #e5e7eb !important;
          border-color: #1f2937 !important;
        }
        .control-panel .selectize-dropdown {
          background-color: #020617 !important;
          color: #e5e7eb !important;
        }
        .control-panel .btn-primary {
          width: 100%;
          margin-top: 8px;
          background: #2563eb;
          border-color: #2563eb;
        }
        .control-panel .btn-primary:hover {
          background: #1d4ed8;
          border-color: #1d4ed8;
        }
        .card {
          background: #020617;
          border-radius: 10px;
          box-shadow: 0 1px 4px rgba(15, 23, 42, 0.7);
          padding: 14px 16px 10px 16px;
          margin-bottom: 18px;
          border: 1px solid #1e293b;
        }
        .card-title {
          margin-top: 0;
          margin-bottom: 10px;
          font-size: 16px;
          font-weight: 600;
          color: #f9fafb;
          text-align: center;
        }
        #summary {
          background: #020617;
          color: #e5e7eb;
          border-radius: 8px;
          padding: 10px 12px;
          font-family: Menlo, Monaco, Consolas, 'Courier New', monospace;
          font-size: 12px;
          max-height: 200px;
          overflow-y: auto;
          border: 1px solid #1e293b;
        }
      "))
    ),
    shiny::div(
      class = "app-container",
      shiny::fluidRow(
        shiny::column(
          width = 12,
          shiny::h3("arXiv Cyber Threat Intelligence Dashboard",
                    class = "app-header-title"),
          shiny::p(
            "Сбор и анализ публикаций по кибербезопасности из arXiv: фильтрация, тематическая категоризация и визуальная разведка данных.",
            class = "app-header-subtitle"
          )
        )
      ),
      shiny::fluidRow(
        shiny::column(
          width = 3,
          class = "sidebar-col",
          shiny::div(
            class = "control-panel",
            shiny::selectInput(
              "categories",
              label = "arXiv категории:",
              choices = c("cs.CR", "cs.NI", "cs.AI", "cs.SE", "cs.DC",
                          "cs.LG", "cs.CY", "cs.DB", "cs.IR", "stat.ML", "math.OC"),
              selected = c("cs.CR", "cs.NI"),
              multiple = TRUE
            ),
            shiny::sliderInput(
              "max_results",
              label = "Количество статей (max_results):",
              min = 10, max = 200, value = 100, step = 10
            ),
            shiny::radioButtons(
              "category_mode",
              label = "Режим категоризации:",
              choices = c("primary", "multi"),
              selected = "primary",
              inline = TRUE
            ),
            shiny::helpText(
              "primary — каждой статье назначается одна основная тема.",
              " multi — статье может соответствовать несколько тем."
            ),
            shiny::checkboxInput(
              "strict_mode",
              label = "Строгий режим фильтрации кибербезопасности",
              value = TRUE
            ),
            shiny::helpText(
              "Если включено — фильтр использует расширенный список кибертерминов",
              " (APT, threat intelligence, SOC, SIEM и т.п.), отбрасывая всё,",
              " что даже отдалённо не похоже на кибербезопасность."
            ),
            shiny::actionButton("load_btn", "Загрузить и проанализировать",
                                class = "btn-primary")
          )
        ),
        shiny::column(
          width = 9,
          class = "content-col",
          shiny::fluidRow(
            shiny::column(
              width = 12,
              shiny::div(
                class = "card",
                shiny::h4("Краткий отчёт", class = "card-title"),
                shiny::verbatimTextOutput("summary")
              )
            )
          ),
          shiny::fluidRow(
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Распределение статей по тематикам",
                          class = "card-title"),
                shiny::plotOutput("cat_plot", height = "300px")
              )
            ),
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Динамика публикаций во времени",
                          class = "card-title"),
                shiny::plotOutput("time_plot", height = "300px")
              )
            )
          ),
          shiny::fluidRow(
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Распределение числа авторов на статью",
                          class = "card-title"),
                shiny::plotOutput("authors_per_paper_plot", height = "260px")
              )
            ),
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Топ‑10 авторов по числу статей",
                          class = "card-title"),
                shiny::plotOutput("top_authors_plot", height = "260px")
              )
            )
          ),
          shiny::fluidRow(
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Распределение исходных arXiv категорий",
                          class = "card-title"),
                shiny::plotOutput("arxiv_cat_plot", height = "260px")
              )
            ),
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Распределение уверенности категоризации",
                          class = "card-title"),
                shiny::plotOutput("confidence_hist", height = "260px")
              )
            )
          ),
          shiny::fluidRow(
            shiny::column(
              width = 12,
              shiny::div(
                class = "card",
                shiny::h4("Пересечение arXiv и security‑категорий",
                          class = "card-title"),
                shiny::plotOutput("security_vs_arxiv_heatmap",
                                  height = "360px")
              )
            )
          ),
          shiny::fluidRow(
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Воронка пайплайна (raw → filtered → categorized)",
                          class = "card-title"),
                shiny::plotOutput("pipeline_funnel", height = "260px")
              )
            ),
            shiny::column(
              width = 6,
              shiny::div(
                class = "card",
                shiny::h4("Число security‑категорий на статью (multi‑режим)",
                          class = "card-title"),
                shiny::plotOutput("multi_categories_hist", height = "260px")
              )
            )
          )
        )
      )
    )
  )

  server <- function(input, output, session) {
    data_reactive <- shiny::eventReactive(input$load_btn, {
      shiny::validate(shiny::need(length(input$categories) > 0,
                                  "Выберите хотя бы одну категорию"))

      # 1. Сбор данных
      raw <- fetch_arxiv_data(
        categories = input$categories,
        max_results = input$max_results,
        verbose = TRUE
      )

      # 2. Фильтрация по кибербезопасности
      filtered <- filter_cybersecurity(raw, strict_mode = input$strict_mode)

      # 3. Категоризация
      categorized <- categorize_articles(
        filtered,
        mode = input$category_mode,
        verbose = TRUE
      )

      list(
        raw = raw,
        filtered = filtered,
        categorized = categorized
      )
    })

    output$summary <- shiny::renderText({
      d <- data_reactive()
      shiny::req(d)
      paste0(
        "Всего загружено из arXiv: ", nrow(d$raw), " записей\n",
        "После фильтрации по кибербезопасности: ", nrow(d$filtered), " записей\n",
        "После категоризации: ", nrow(d$categorized), " записей\n",
        "Режим категоризации: ", input$category_mode, "\n",
        "primary — каждой статье назначается одна основная тема безопасности.\n",
        "multi   — статье может соответствовать сразу несколько тем безопасности."
      )
    })

    output$cat_plot <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      plot_category_distribution(d$categorized, mode = input$category_mode)
    })

    output$time_plot <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      plot_publication_timeline(
        d$categorized,
        by = "month",
        facet_by_category = (input$category_mode == "primary")
      )
    })

    # Распределение числа авторов на статью
    output$authors_per_paper_plot <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      if (!"authors" %in% names(d$categorized)) return(NULL)

      df <- d$categorized %>%
        dplyr::mutate(author_count = lengths(authors)) %>%
        dplyr::filter(!is.na(author_count), author_count > 0)

      if (nrow(df) == 0) return(NULL)

      stats <- df %>%
        dplyr::count(author_count, name = "n")

      ggplot2::ggplot(stats, ggplot2::aes(x = factor(author_count), y = n)) +
        ggplot2::geom_col(fill = "#1B9E77") +
        ggplot2::labs(
          x = "Число авторов у статьи",
          y = "Количество статей",
          title = "Распределение числа авторов на статью"
        ) +
        ggplot2::theme_minimal(base_size = 12)
    })

    # Топ‑10 авторов по числу статей
    output$top_authors_plot <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      if (!"authors" %in% names(d$categorized)) return(NULL)

      authors_long <- d$categorized %>%
        tidyr::unnest_longer(authors, values_to = "author_name") %>%
        dplyr::filter(!is.na(author_name) & author_name != "")

      if (nrow(authors_long) == 0) return(NULL)

      top_authors <- authors_long %>%
        dplyr::count(author_name, sort = TRUE, name = "n") %>%
        dplyr::slice_head(n = 10) %>%
        dplyr::mutate(
          author_name = factor(author_name, levels = rev(author_name))
        )

      ggplot2::ggplot(top_authors,
                      ggplot2::aes(x = author_name, y = n)) +
        ggplot2::geom_col(fill = "#D95F02") +
        ggplot2::coord_flip() +
        ggplot2::labs(
          x = "Автор",
          y = "Количество статей",
          title = "Топ‑10 авторов по числу статей"
        ) +
        ggplot2::theme_minimal(base_size = 12)
    })

    # Распределение исходных arXiv категорий
    output$arxiv_cat_plot <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      src <- if (!is.null(d$filtered) && nrow(d$filtered) > 0) d$filtered else d$raw
      if (!"categories" %in% names(src)) return(NULL)

      cats <- src %>%
        tidyr::unnest_longer(categories, values_to = "category_term") %>%
        dplyr::filter(!is.na(category_term) & category_term != "")

      if (nrow(cats) == 0) return(NULL)

      stats <- cats %>%
        dplyr::count(category_term, sort = TRUE, name = "n") %>%
        dplyr::slice_head(n = 15) %>%
        dplyr::mutate(
          category_term = factor(category_term, levels = rev(category_term))
        )

      ggplot2::ggplot(stats,
                      ggplot2::aes(x = category_term, y = n)) +
        ggplot2::geom_col(fill = "#7570B3") +
        ggplot2::coord_flip() +
        ggplot2::labs(
          x = "arXiv категория",
          y = "Количество статей",
          title = "Распределение исходных arXiv категорий (топ‑15)"
        ) +
        ggplot2::theme_minimal(base_size = 12)
    })

    # Тепловая карта: arXiv категория × security‑категория
    output$security_vs_arxiv_heatmap <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      df <- d$categorized
      if (!"categories" %in% names(df)) return(NULL)

      if (input$category_mode == "primary" && "security_category" %in% names(df)) {
        data_hm <- df %>%
          tidyr::unnest_longer(categories, values_to = "arxiv_cat") %>%
          dplyr::filter(!is.na(arxiv_cat), !is.na(security_category)) %>%
          dplyr::count(arxiv_cat, security_category, name = "n")
      } else if (input$category_mode == "multi" &&
                 "security_categories" %in% names(df)) {
        data_hm <- df %>%
          tidyr::unnest_longer(categories, values_to = "arxiv_cat") %>%
          tidyr::unnest_longer(security_categories,
                               values_to = "security_category") %>%
          dplyr::filter(!is.na(arxiv_cat), !is.na(security_category)) %>%
          dplyr::count(arxiv_cat, security_category, name = "n")
      } else {
        return(NULL)
      }

      if (nrow(data_hm) == 0) return(NULL)

      ggplot2::ggplot(data_hm,
                      ggplot2::aes(x = arxiv_cat, y = security_category,
                                   fill = n)) +
        ggplot2::geom_tile() +
        ggplot2::scale_fill_viridis_c(option = "C") +
        ggplot2::labs(
          x = "arXiv категория",
          y = "Security‑категория",
          fill = "Статей",
          title = "Пересечение исходных и security‑категорий"
        ) +
        ggplot2::theme_minimal(base_size = 11) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
    })

    # Распределение уверенности категоризации
    output$confidence_hist <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      if (!"category_confidence" %in% names(d$categorized)) return(NULL)

      df <- d$categorized %>%
        dplyr::filter(!is.na(category_confidence))

      if (nrow(df) == 0) return(NULL)

      ggplot2::ggplot(df,
                      ggplot2::aes(x = category_confidence)) +
        ggplot2::geom_histogram(fill = "#E7298A", bins = 20, color = "white") +
        ggplot2::labs(
          x = "category_confidence",
          y = "Количество статей",
          title = "Распределение уверенности категоризации"
        ) +
        ggplot2::theme_minimal(base_size = 12)
    })

    # Воронка пайплайна: raw -> filtered -> categorized
    output$pipeline_funnel <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      counts <- tibble::tibble(
        stage = factor(
          c("raw", "filtered", "categorized"),
          levels = c("raw", "filtered", "categorized")
        ),
        n = c(
          nrow(d$raw),
          nrow(d$filtered),
          nrow(d$categorized)
        )
      )

      ggplot2::ggplot(counts,
                      ggplot2::aes(x = stage, y = n)) +
        ggplot2::geom_col(fill = "#66A61E") +
        ggplot2::geom_text(ggplot2::aes(label = n), vjust = -0.3) +
        ggplot2::labs(
          x = "Этап пайплайна",
          y = "Количество записей",
          title = "Воронка: от сырых данных до категоризированных"
        ) +
        ggplot2::theme_minimal(base_size = 12)
    })

    # Для multi‑режима: сколько security‑категорий на одну статью
    output$multi_categories_hist <- shiny::renderPlot({
      d <- data_reactive()
      shiny::req(d)
      if (!"security_categories" %in% names(d$categorized)) return(NULL)

      df <- d$categorized %>%
        dplyr::mutate(cat_count = lengths(security_categories)) %>%
        dplyr::filter(!is.na(cat_count) & cat_count > 0)

      if (nrow(df) == 0) return(NULL)

      ggplot2::ggplot(df,
                      ggplot2::aes(x = cat_count)) +
        ggplot2::geom_histogram(fill = "#E6AB02", bins = 10, color = "white") +
        ggplot2::scale_x_continuous(breaks = seq_len(max(df$cat_count))) +
        ggplot2::labs(
          x = "Число security‑категорий у статьи",
          y = "Количество статей",
          title = "Распределение числа security‑категорий (multi‑режим)"
        ) +
        ggplot2::theme_minimal(base_size = 12)
    })
  }

  shiny::shinyApp(ui, server) |>
    shiny::runApp(host = host, port = port)
}

