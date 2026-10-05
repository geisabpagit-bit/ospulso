#!/usr/bin/perl
use strict;
use warnings;
use utf8;

print "Content-Type: text/html; charset=UTF-8\n\n";
print <<'HTML';
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Prueba de Sincronización - OsPulso</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
            display: flex; 
            align-items: center; 
            justify-content: center; 
            min-height: 100vh; 
            margin: 0; 
            background: #f0f4f8; 
        }
        .card { 
            background: white; 
            padding: 2.5rem; 
            border-radius: 16px; 
            box-shadow: 0 12px 35px rgba(10,42,102,0.12); 
            text-align: center; 
            max-width: 480px; 
            border: 2px solid #19b7a5; 
            margin: 1rem;
        }
        .icon { 
            font-size: 3.5rem; 
            margin-bottom: 1rem; 
        }
        h1 { 
            color: #0a2a66; 
            margin: 0 0 0.5rem 0; 
            font-size: 1.6rem; 
            font-weight: 800;
        }
        p { 
            color: #64748b; 
            margin: 0 0 1.5rem 0; 
            font-size: 0.95rem; 
            line-height: 1.5;
        }
        .badge { 
            display: inline-block;
            background: #e0f2fe; 
            color: #0284c7; 
            padding: 8px 16px; 
            border-radius: 20px; 
            font-weight: 700; 
            font-size: 0.85rem; 
            border: 1px solid #bae6fd;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="icon">🚀</div>
        <h1>¡Sincronización Exitosa!</h1>
        <p>Este archivo fue generado en tu máquina local, enviado a GitHub y sincronizado en <strong>ospulso.com</strong> mediante tu comando de Git.</p>
        <span class="badge">✅ Perl CGI + Git Fetch/Reset + Permisos 755 Operativos</span>
    </div>
</body>
</html>
HTML
