FROM certbot/certbot

LABEL MAINTAINER=corban@utos.org

COPY entrypoint.sh /scripts/entrypoint.sh
COPY cronjob.cron /scripts/cronjob.cron

RUN chmod +x /scripts/entrypoint.sh
RUN apk add --no-cache apk-cron bash
RUN crontab /scripts/cronjob.cron

ENTRYPOINT ["/scripts/entrypoint.sh"]