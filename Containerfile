FROM python:3.11.11-bookworm as builder

ENV LANG=en_US.UTF-8 \
    PATH="/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_CACHE_DIR=/tmp/pip.cache \

RUN set -ex \
 && apt-get update -qq \
 && apt-get install \
        --no-install-recommends \
        --no-install-suggests \
        --yes git git-lfs libpq5 skopeo libxml2 libxmlsec1 \
              gcc libpq-dev libldap-dev libsasl2-dev libxmlsec1-dev \
 && python3 -m venv /venv \
 && pip install --upgrade --no-cache-dir pip wheel

WORKDIR /app
COPY . .
RUN set -ex \
 && pip install --requirement requirements/requirements.insights.txt \
 && pip install --no-deps --editable . \
 && django-admin collectstatic

FROM python:3.11.11-bookworm
WORKDIR /app
ENV LANG=en_US.UTF-8 \
    HOME="/app" \
    PATH="/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PULP_SETTINGS=/etc/pulp/settings.py \
    DJANGO_SETTINGS_MODULE=pulpcore.app.settings

RUN useradd --uid 1000 --gid 0 --home-dir "${HOME}" --no-create-home galaxy
RUN set -ex \
 && apt-get update -qq \
 && apt-get install \
        --no-install-recommends \
        --no-install-suggests \
        --yes git git-lfs openssl libpq5 skopeo libxml2 libxmlsec1 \
 && rm -rf \
        /var/cache/apt/* \
        /var/lib/apt/lists/* \
        /var/log/apt/* \
        /var/log/*.log

COPY --from=builder /venv/ /venv/
COPY --from=builder /app/galaxy_ng/ /app/galaxy_ng/
COPY --from=builder --chmod=644 /app/ansible.cfg /etc/ansible/ansible.cfg
COPY --from=builder --chmod=644 /app/docker/etc/settings.py /etc/pulp/settings.py
COPY --from=builder --chmod=755 /app/docker/entrypoint.sh /entrypoint.sh
COPY --from=builder --chmod=755 /app/docker/bin/* /usr/local/bin/
COPY --from=builder --chmod=775 /app/galaxy-operator/bin/* /usr/bin/
RUN install -dm 0775 -o galaxy \
        /var/lib/pulp/{artifact,assets,media,scripts,tmp} \
        /etc/pulp/{certs,keys} \
        /tmp/ansible

USER galaxy
WORKDIR /app
VOLUME [ "/var/lib/pulp/artifact", "/var/lib/pulp/tmp", "/tmp/ansible" ]
ENTRYPOINT [ "/entrypoint.sh" ]
