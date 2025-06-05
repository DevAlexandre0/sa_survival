CREATE TABLE IF NOT EXISTS `player_survival_data` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL COLLATE 'utf8mb4_unicode_ci',
    `data` LONGTEXT NOT NULL COLLATE 'utf8mb4_unicode_ci',
    `last_updated` TIMESTAMP NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
    PRIMARY KEY (`id`) USING BTREE,
    UNIQUE INDEX `identifier` (`identifier`) USING BTREE
) COLLATE='utf8mb4_unicode_ci' ENGINE=InnoDB;