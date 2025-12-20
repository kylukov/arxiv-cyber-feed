# syntax=docker/dockerfile:1.4
# ============================
# Stage 1 — Build R package
# ============================
FROM rocker/r-ver:4.4.0 AS builder

# Install system dependencies (cached layer)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    git libgit2-dev libicu-dev libssh2-1-dev \
    make g++ pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install remotes (faster than devtools) with cache
RUN --mount=type=cache,target=/root/.cache/R/renv/cache/v5,sharing=locked \
    R -e "install.packages('remotes', repos='https://cloud.r-project.org/', Ncpus=2)"

WORKDIR /build

# Copy DESCRIPTION and NAMESPACE first (cache-friendly)
COPY DESCRIPTION NAMESPACE ./

# Install dependencies with cache mount for R packages (including Suggests for roxygen2)
RUN --mount=type=cache,target=/root/.cache/R/renv/cache/v5,sharing=locked \
    R -e "remotes::install_deps('.', dependencies = c('Depends', 'Imports', 'Suggests'), upgrade = 'never', repos='https://cloud.r-project.org/', Ncpus=2)"

# Copy R source files (changes more frequently)
COPY R/ ./R/

# Copy man directory (documentation - will be regenerated but needed for structure)
COPY man/ ./man/

# Copy tests directory (needed for package structure)
COPY tests/ ./tests/

# Remove any old tar.gz or installed package remnants
RUN rm -f /build/*.tar.gz && \
    rm -rf /usr/local/lib/R/site-library/arxivThreatIntel

# Install devtools (may be needed by roxygen2) and verify roxygen2
RUN --mount=type=cache,target=/root/.cache/R/renv/cache/v5,sharing=locked \
    R -e " \
    options(repos = c(CRAN = 'https://cloud.r-project.org/')); \
    if (!requireNamespace('devtools', quietly=TRUE)) { \
      cat('Installing devtools...\n'); \
      install.packages('devtools', Ncpus=2, dependencies=TRUE); \
    }; \
    if (!requireNamespace('roxygen2', quietly=TRUE)) { \
      cat('roxygen2 not found, installing...\n'); \
      install.packages('roxygen2', Ncpus=2, dependencies=TRUE); \
    }; \
    cat('roxygen2 is available:', requireNamespace('roxygen2', quietly=TRUE), '\n')"

# Generate documentation - try devtools::document() first (more reliable), fallback to roxygen2
RUN R -e " \
    cat('Starting documentation generation...\n'); \
    cat('Working directory:', getwd(), '\n'); \
    cat('R files found:', length(list.files('R', pattern='.R$')), '\n'); \
    success <- FALSE; \
    if (requireNamespace('devtools', quietly=TRUE)) { \
      cat('Trying devtools::document()...\n'); \
      tryCatch({ \
        library(devtools); \
        document(); \
        cat('Documentation generated successfully with devtools\n'); \
        success <- TRUE; \
      }, error = function(e) { \
        cat('devtools::document() failed:', conditionMessage(e), '\n'); \
      }); \
    }; \
    if (!success && requireNamespace('roxygen2', quietly=TRUE)) { \
      cat('Trying roxygen2::roxygenise()...\n'); \
      tryCatch({ \
        library(roxygen2); \
        roxygenise(); \
        cat('Documentation generated successfully with roxygen2\n'); \
        success <- TRUE; \
      }, error = function(e) { \
        cat('roxygen2::roxygenise() failed:', conditionMessage(e), '\n'); \
      }); \
    }; \
    if (!success) { \
      if (!file.exists('NAMESPACE')) { \
        stop('Failed to generate documentation and NAMESPACE is missing') \
      } else { \
        cat('WARNING: Documentation generation failed but NAMESPACE exists. Continuing...\n'); \
      } \
    }"

# Build package
RUN R CMD build .

# Install freshly built package
RUN R CMD INSTALL *.tar.gz


# ============================
# Stage 2 — Runtime image
# ============================
FROM rocker/r-ver:4.4.0

# Set working directory
WORKDIR /app

# Copy installed package from builder
COPY --from=builder /usr/local/lib/R/site-library /usr/local/lib/R/site-library

# Default command
CMD ["R"]
