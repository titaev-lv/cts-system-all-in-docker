-- Bootstrap users for MySQL mTLS clients.
-- Executed by docker-entrypoint on first initialization when data dir is empty.

CREATE USER IF NOT EXISTS `cts-core`@`%` IDENTIFIED BY 'root' REQUIRE X509;
CREATE USER IF NOT EXISTS `cts-web`@`%` IDENTIFIED BY 'root' REQUIRE X509;

ALTER USER `cts-core`@`%` IDENTIFIED BY 'root' REQUIRE X509;
ALTER USER `cts-web`@`%` IDENTIFIED BY 'root' REQUIRE X509;

GRANT ALL PRIVILEGES ON `ct_system`.* TO `cts-core`@`%`;
GRANT ALL PRIVILEGES ON `ct_system`.* TO `cts-web`@`%`;

FLUSH PRIVILEGES;
