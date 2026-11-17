# justcreativegames.com - statik site (nginx)
FROM nginx:stable-alpine
LABEL project="jcg_site"
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY *.html style.css home.css home.js favicon.png robots.txt sitemap.xml /usr/share/nginx/html/
COPY assets /usr/share/nginx/html/assets
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
