-- Additive migration. Existing business tables and data are not replaced.
CREATE TABLE IF NOT EXISTS ejecutivo_acceso (
 usuario_id INT UNSIGNED PRIMARY KEY,
 entidad_id SMALLINT UNSIGNED NOT NULL,
 totp_secret TEXT NULL,
 totp_last_step BIGINT NOT NULL DEFAULT -1,
 FOREIGN KEY (usuario_id) REFERENCES usuario(usuario_id) ON DELETE CASCADE,
 FOREIGN KEY (entidad_id) REFERENCES cat_entidad_federativa(entidad_id)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS ejecutivo_token (
 token_hash CHAR(64) PRIMARY KEY,
 usuario_id INT UNSIGNED NOT NULL,
 tipo VARCHAR(20) NOT NULL,
 expira DATETIME NOT NULL,
 usado DATETIME NULL,
 creado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 FOREIGN KEY (usuario_id) REFERENCES usuario(usuario_id) ON DELETE CASCADE,
 INDEX idx_token_usuario (usuario_id, tipo),
 INDEX idx_token_expira (expira)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS ejecutivo_acceso_solicitud (
 id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
 correo VARCHAR(180) NOT NULL UNIQUE,
 password_hash VARCHAR(255) NOT NULL,
 creado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS ejecutivo_limite (
 clave CHAR(64) PRIMARY KEY,
 ventana BIGINT NOT NULL,
 intentos INT NOT NULL DEFAULT 1
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS ejecutivo_registro (
 solicitud_id INT UNSIGNED PRIMARY KEY,
 usuario_id INT UNSIGNED NOT NULL,
 idempotencia CHAR(36) NOT NULL,
 creado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE KEY uq_registro_reintento (usuario_id, idempotencia),
 FOREIGN KEY (solicitud_id) REFERENCES solicitud_apoyo(solicitud_id),
 FOREIGN KEY (usuario_id) REFERENCES usuario(usuario_id)
) ENGINE=InnoDB;
