<?php
/* Configuration de base */
$cfg['blowfish_secret'] = getenv('PHPMYADMIN_BLOWFISH_SECRET') ?: 'votreClefSecreteRandomisee';
$cfg['Servers'][1]['auth_type'] = 'cookie';
$cfg['Servers'][1]['host'] = getenv('MYSQL_HOST');
$cfg['Servers'][1]['port'] = 3306;
$cfg['Servers'][1]['AllowNoPassword'] = false;
/* Pas de connexion root : utiliser MYSQL_USER (ou ./lamp.sh mysql pour root) */
$cfg['Servers'][1]['AllowRoot'] = false;

/* Augmenter la taille d'upload */
$cfg['UploadDir'] = '';
$cfg['SaveDir'] = '';
$cfg['ExecTimeLimit'] = 300;

/* Vérification des permissions désactivée : ce fichier est monté depuis l'hôte
   et peut y apparaître accessible en écriture à tous (montages Windows / Docker
   Desktop), ce qui bloquerait phpMyAdmin. Sur un serveur, gardez-le non
   modifiable par les autres utilisateurs : chmod 644 config/phpmyadmin/config.inc.php */
$cfg['CheckConfigurationPermissions'] = false;
