# syntax=docker/dockerfile:1.4

# ============================
# Stage 1 — Build R package
# ============================
FROM rocker/r-ver:4.4.0 AS builder

# System deps (минимальные, pak тянет бинарники)
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

WORKDIR /build

# ----------------------------
# Install pak (один раз)
# ----------------------------
RUN --mount=type=cache,target=/root/.cache/R/pak \
    R -e " \
      options(repos = c( \
        CRAN = 'https://cloud.r-project.org' \
      )); \
      install.packages('pak', Ncpus = 2) \
    "

# ----------------------------
# Copy metadata first (cache!)
# ----------------------------
COPY DESCRIPTION NAMESPACE ./

# ----------------------------
# Install deps via pak (BINARIES ONLY)
# ----------------------------
RUN --mount=type=cache,target=/root/.cache/R/pak \
    R -e " \
      Sys.setenv( \
        PAK_BUILD_BINARY = 'false', \
        PAK_USE_BUNDLED_LIBRARIES = 'true' \
      ); \
      options(pkgType = 'binary'); \
      pak::pkg_install( \
        '.', \
        dependencies = c('Depends', 'Imports', 'Suggests') \
      ) \
    "

# ----------------------------
# Copy rest of package
# ----------------------------
COPY R/ ./R/
COPY man/ ./man/
COPY tests/ ./tests/

# ----------------------------
# Generate documentation
# ----------------------------
RUN R -e " \
    Sys.setenv(PAK_BUILD_BINARY = 'false'); \
    options(pkgType = 'binary'); \
    pak::pkg_install(c('devtools', 'roxygen2')); \
    devtools::document() \
"

# ----------------------------
# Build & install package
# ----------------------------
RUN R CMD build . && \
    R CMD INSTALL *.tar.gz


# ============================
# Stage 2 — Runtime
# ============================
FROM rocker/r-ver:4.4.0

WORKDIR /app

COPY --from=builder /usr/local/lib/R/site-library \
                     /usr/local/lib/R/site-library

EXPOSE 3838

CMD ["Rscript", "-e", "library(arxivThreatIntel); run_visual_dashboard(host='0.0.0.0', port=3838)"]