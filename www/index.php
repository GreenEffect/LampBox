<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>LampBox</title>
        <link rel="shortcut icon" href="/assets/images/LampBox_Logo.png" type="image/png">
        <link rel="stylesheet" href="/assets/css/bulma.min.css">
    </head>
    <body>
        <section class="hero is-medium is-info is-bold">
            <div class="hero-body">
                <div class="container has-text-centered">
                    <img src="/assets/images/LampBox_Logo.png" alt="LampBox Logo" style="max-width: 200px; margin-bottom: 20px;">
                    <h1 class="title">
                        LampBox
                    </h1>
                    <h2 class="subtitle">
                        Local development environment
                    </h2>
                </div>
            </div>
        </section>
        <section class="section">
            <div class="container">
                <div class="columns">
                    <div class="column">
                        <h3 class="title is-3 has-text-centered">Environment</h3>
                        <hr>
                        <div class="content">
                            <ul>
                                <li><?= apache_get_version(); ?></li>
                                <li>PHP <?= phpversion(); ?></li>
                                <li>
                                    <?php
                                        $host = getenv('MYSQL_HOST'); // Nom d'hôte de la base de données
                                        $user = "root"; // Nom d'utilisateur
                                        $password = $_ENV['MYSQL_ROOT_PASSWORD']; // Mot de passe (depuis l'environnement)

                                        try {
                                            $dsn = "mysql:host=$host;charset=utf8mb4"; // Data Source Name
                                            $options = [
                                                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                                                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                                                PDO::ATTR_EMULATE_PREPARES   => false,
                                            ];
                                            $pdo = new PDO($dsn, $user, $password, $options);

                                            // Sélection de la base de données (équivalent de mysqli_connect avec le 4ème paramètre à null)
                                            $pdo->exec("USE information_schema"); // ou le nom de votre base de données

                                            // Affichage de la version du serveur (équivalent de mysqli_get_server_info)
                                            $stmt = $pdo->query("SELECT VERSION()");
                                            $serverVersion = $stmt->fetchColumn();
                                            printf("MySQL Server %s", $serverVersion);

                                            // Pas besoin de fermer explicitement la connexion avec $pdo = null; en fin de script, PHP le fait automatiquement.
                                        } catch (PDOException $e) {
                                            printf("MySQL connection failed: %s", $e->getMessage());
                                        }

                                    ?>
                                </li>
                            </ul>
                        </div>
                    </div>
                    <div class="column">
                        <h3 class="title is-3 has-text-centered">Quick Links</h3>
                        <hr>
                        <div class="content">
                            <?php

                                function getCurrentDomain() {
                                    $protocol = "https://";
                                    $host = isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : (isset($_SERVER['SERVER_NAME']) ? $_SERVER['SERVER_NAME'] : null);
                                    $port = isset($_SERVER['SERVER_PORT']) ? $_SERVER['SERVER_PORT'] : null;

                                    if (!$host) {
                                        return null; // Impossible de déterminer le domaine
                                    }

                                    $domain = $protocol . $host;
                                    if ($port && !in_array($port, [80, 443])) {
                                        $domain .= ':' . $port;
                                    }

                                    return $domain;
                                }

                                $currentDomain = getCurrentDomain();

                
                                ?>
                            <ul>
                                <li><a href="/phpinfo.php">phpinfo()</a></li>
                                <li><a href="/test_db_pdo.php">Test DB Connection with PDO</a></li>
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
        </section>
        <footer class="footer">
            <div class="content has-text-centered">
                <p>
                    
                </p>
            </div>
        </footer>
    </body>
</html>
