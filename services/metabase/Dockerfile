# Metabase OSS 65.4.4 (official image, pinned by digest) plus a Railway launcher that sizes
# the Java heap to the service's memory limit and completes the first-run setup itself.
ARG METABASE_IMAGE=metabase/metabase:v0.65.4.4@sha256:06b66bf50d5b46ad632a836aeb62149eaab768033f9d3dae72ad4b10e6427590
FROM ${METABASE_IMAGE}

COPY --chmod=0755 railway/ /app/railway/

EXPOSE 3000
ENTRYPOINT ["/app/railway/start.sh"]
