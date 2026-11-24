# Open Agent Connector API (FastAPI), built from upstream commit 3cde269 (upstream publishes no release tags or images).
FROM python:3.11.18-slim@sha256:139bddfb66e90ab739a881d4ce70cd49c22f57837463fba3cd59639091313df1

ARG OAC_COMMIT=3cde26911964ebbd4b7cb6206535b8629aa2a7ce
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Upstream source at the pinned commit (only the server/ folder is kept).
RUN python - <<PY
import io, tarfile, urllib.request
url = "https://codeload.github.com/Anil-matcha/open-agent-connector/tar.gz/${OAC_COMMIT}"
data = urllib.request.urlopen(url, timeout=120).read()
with tarfile.open(fileobj=io.BytesIO(data)) as t:
    for m in t.getmembers():
        parts = m.name.split("/", 2)
        if len(parts) == 3 and parts[1] == "server" and parts[2] and not parts[2].startswith("tests"):
            m.name = parts[2]
            t.extract(m, "/app", filter="data")
PY

# Exact versions resolved from upstream's requirements.txt on 2026-11-24.
COPY requirements.lock.txt /app/requirements.lock.txt
RUN pip install --no-compile -r /app/requirements.lock.txt && mkdir -p /app/data

COPY start.sh /usr/local/bin/oac-server
COPY run.py /usr/local/lib/oac-run.py
RUN chmod 755 /usr/local/bin/oac-server

ENV PORT=8000
EXPOSE 8000
CMD ["/usr/local/bin/oac-server"]
