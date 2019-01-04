FROM nginx:mainline

LABEL MAINTAINER=corban@utos.org

COPY entrypoint.sh /scripts/entrypoint.sh

COPY options-ssl-nginx.conf /assets/options-ssl-nginx.conf

COPY generic-default.conf /etc/nginx/conf.d/default.conf

RUN chmod +x /scripts/entrypoint.sh
RUN apt-get update && apt-get install openssl

ENTRYPOINT [ "/scripts/entrypoint.sh" ]
