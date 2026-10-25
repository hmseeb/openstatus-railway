# Upstream dashboard with the onboarding "first check" pointed at this project's
# cron service (images/cron/preview.py) instead of OpenStatus's cloud checkers.
# Those cannot answer a self-hosted install, so onboarding always said "Couldn't
# reach <url>", and every run sent this deploy's CRON_SECRET to them.
FROM ghcr.io/openstatushq/openstatus-dashboard:3fa4995
USER 0:0
RUN files=$(grep -rlE 'openstatus-checker\.(fly\.dev|koyeb\.app)/ping|railway-proxy-production-9cb1\.up\.railway\.app/ping' /app/apps/dashboard/.next/server) \
    && [ -n "$files" ] \
    && sed -i -E 's#https://(openstatus-checker\.(fly\.dev|koyeb\.app)|railway-proxy-production-9cb1\.up\.railway\.app)/ping#http://cron.railway.internal:8081/ping#g' $files \
    && ! grep -rqE 'openstatus-checker\.(fly\.dev|koyeb\.app)/ping|railway-proxy-production-9cb1' /app/apps/dashboard/.next/server \
    && grep -rl 'cron.railway.internal:8081/ping' /app/apps/dashboard/.next/server
USER 1000:1000
