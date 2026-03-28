<?php
$email = 'admin@test.com';
try {
    $db = new PDO('sqlite:database/database.sqlite');
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $stmt = $db->prepare('SELECT id FROM personnel WHERE email = :e');
    $stmt->execute([':e' => $email]);
    $id = $stmt->fetchColumn();

    if (!$id) {
        $pw = password_hash('changeme123', PASSWORD_BCRYPT);
        $ins = $db->prepare('INSERT INTO personnel (nom,email,mot_de_passe,role,actif,created_at) VALUES (:nom,:email,:pw,:role,1,datetime("now"))');
        $ins->execute([':nom' => 'Admin', ':email' => $email, ':pw' => $pw, ':role' => 'ADMIN']);
        $id = $db->lastInsertId();
        echo "created_user_id:$id\n";
    } else {
        $db->prepare('UPDATE personnel SET role = :role, actif = 1 WHERE id = :id')->execute([':role' => 'ADMIN', ':id' => $id]);
        echo "updated_user_id:$id\n";
    }

    $token = bin2hex(random_bytes(30));
    $hash = hash('sha256', $token);
    $db->prepare('INSERT INTO auth_tokens (token,personnel_id,created_at,expires_at) VALUES(:t,:pid,datetime("now"), datetime("now", "+30 minutes"))')
        ->execute([':t' => $hash, ':pid' => $id]);

    echo $token . PHP_EOL;
} catch (Exception $e) {
    echo 'ERR:' . $e->getMessage() . PHP_EOL;
    exit(1);
}
