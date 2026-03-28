<?php
// Usage: php cleanup_tokens_mysql.php [days=7] [email=optional]
$env = file_get_contents(__DIR__ . '/../.env');
$get = function($k) use ($env) {
    if (preg_match('/^'.preg_quote($k).'=(.*)$/m', $env, $m)) return trim($m[1]);
    return null;
};
$host = $get('DB_HOST') ?: '127.0.0.1';
$db = $get('DB_DATABASE') ?: 'mekong';
$user = $get('DB_USERNAME') ?: 'root';
$pass = $get('DB_PASSWORD') ?: '';
$days = isset($argv[1]) && is_numeric($argv[1]) ? intval($argv[1]) : 7;
$email = isset($argv[2]) ? $argv[2] : null;
try {
    $pdo = new PDO("mysql:host=$host;dbname=$db;charset=utf8mb4", $user, $pass, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);

    // Delete tokens that are expired (expires_at < NOW())
    $stmt = $pdo->prepare("DELETE FROM auth_tokens WHERE expires_at IS NOT NULL AND expires_at < NOW()");
    $stmt->execute();
    $deleted1 = $stmt->rowCount();

    // Delete tokens older than $days by created_at
    $stmt = $pdo->prepare("DELETE FROM auth_tokens WHERE created_at < DATE_SUB(NOW(), INTERVAL :d DAY)");
    $stmt->execute([':d' => $days]);
    $deleted2 = $stmt->rowCount();

    $deleted3 = 0;
    if ($email) {
        // find personnel id(s)
        $p = $pdo->prepare('SELECT id FROM personnel WHERE email = :e');
        $p->execute([':e' => $email]);
        $ids = $p->fetchAll(PDO::FETCH_COLUMN);
        if (count($ids) > 0) {
            // delete all tokens for these ids
            $in = implode(',', array_map('intval', $ids));
            $stmt = $pdo->prepare("DELETE FROM auth_tokens WHERE personnel_id IN ($in)");
            $stmt->execute();
            $deleted3 = $stmt->rowCount();
        }
    }

    echo "Deleted expired tokens: $deleted1\n";
    echo "Deleted tokens older than $days days: $deleted2\n";
    if ($email) echo "Deleted tokens for $email: $deleted3\n";
    echo "Done.\n";
} catch (Exception $e) {
    fwrite(STDERR, 'ERR: '.$e->getMessage()."\n");
    exit(1);
}
