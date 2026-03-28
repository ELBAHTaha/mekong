<?php
$env = file_get_contents(__DIR__ . '/../.env');
$get = function($k) use ($env) {
    if (preg_match('/^'.preg_quote($k).'=(.*)$/m', $env, $m)) return trim($m[1]);
    return null;
};
$host = $get('DB_HOST') ?: '127.0.0.1';
$db = $get('DB_DATABASE') ?: 'mekong';
$user = $get('DB_USERNAME') ?: 'root';
$pass = $get('DB_PASSWORD') ?: '';
$email = 'admin@test.com';
try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

    $stmt = $pdo->prepare('SELECT id FROM personnel WHERE email = :e LIMIT 1');
    $stmt->execute([':e' => $email]);
    $id = $stmt->fetchColumn();

    if (!$id) {
        $pw = password_hash('changeme123', PASSWORD_BCRYPT);
        $ins = $pdo->prepare('INSERT INTO personnel (nom,email,mot_de_passe,role,actif,created_at) VALUES (:nom,:email,:pw,:role,1,NOW())');
        $ins->execute([':nom' => 'Admin', ':email' => $email, ':pw' => $pw, ':role' => 'ADMIN']);
        $id = $pdo->lastInsertId();
        echo "created_user_id:$id\n";
    } else {
        $pdo->prepare('UPDATE personnel SET role = :role, actif = 1 WHERE id = :id')->execute([':role' => 'ADMIN', ':id' => $id]);
        echo "updated_user_id:$id\n";
    }

    $token = bin2hex(random_bytes(30));
    $hash = hash('sha256', $token);
    $ins = $pdo->prepare('INSERT INTO auth_tokens (token,personnel_id,created_at,expires_at) VALUES(:t,:pid,NOW(), DATE_ADD(NOW(), INTERVAL 30 MINUTE))');
    $ins->execute([':t' => $hash, ':pid' => $id]);

    echo $token . PHP_EOL;
} catch (Exception $e) {
    echo 'ERR:' . $e->getMessage() . PHP_EOL;
    exit(1);
}
