FROM mysql:9.4.0

# Copy custom entrypoint script
COPY ./init-ca.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-ca.sh
RUN chmod 755 /var/run/mysqld

# Set custom entrypoint
ENTRYPOINT ["/usr/local/bin/init-ca.sh"]
CMD ["mysqld"]
