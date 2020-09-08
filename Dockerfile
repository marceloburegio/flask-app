FROM python:3-alpine AS base
WORKDIR /app

FROM base AS builder
COPY requirements.txt .
RUN \
  python -m venv venv && \
  source venv/bin/activate && \
  pip install -r requirements.txt && \
  rm -f requirements.txt
COPY app.py .

FROM base AS final
ENV PATH="/app/venv/bin:$PATH"
COPY --from=builder /app .
EXPOSE 8000
CMD ["python", "app.py"]