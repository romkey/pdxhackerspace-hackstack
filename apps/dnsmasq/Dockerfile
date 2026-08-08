FROM alpine:edge

RUN apk add --no-cache dnsmasq tini bind-tools bash curl \
    && rm -rf /var/cache/apk/*

# Config and optional supplementary hosts dir
# (mount your real configs over these at runtime)
#COPY dnsmasq.conf /etc/dnsmasq.conf
#RUN mkdir -p /etc/dnsmasq.d /etc/dnsmasq.hosts.d

# Validate config at build time — fails the build on syntax errors
#RUN dnsmasq --test --conf-file=/etc/dnsmasq.conf

# Drop privileges; dnsmasq itself also drops to 'dnsmasq' user via -u below,
# but keeping the process supervisor unprivileged is belt-and-suspenders.
# We stay root in the container so dnsmasq can bind :53, then it drops itself.
EXPOSE 53/udp 53/tcp

# tini handles signals cleanly (SIGTERM -> graceful shutdown, SIGHUP -> reload)
ENTRYPOINT ["/sbin/tini", "--", "dnsmasq"]
CMD ["--keep-in-foreground", \
     "--log-facility=-", \
     "--user=dnsmasq", \
     "--group=dnsmasq", \
     "--conf-file=/etc/dnsmasq.conf"]

#HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
#    CMD nslookup -timeout=2 -type=A health.check.invalid 127.0.0.1 >/dev/null 2>&1 || exit 1
