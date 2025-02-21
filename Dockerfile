# Usar la imagen oficial de NGINX
FROM nginx:alpine

# Copiar un archivo HTML personalizado a la carpeta de NGINX
COPY index.html /usr/share/nginx/html/index.html

# Exponer el puerto 80
EXPOSE 80