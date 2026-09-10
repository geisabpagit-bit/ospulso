#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);
use utf8;
use lib '.';


use CGI;
binmode(STDOUT, ":encoding(UTF-8)"); # basico para los acentos

require 'check_session.pl';

my $q = CGI->new;
my $session_data = check_session();
my $session = $session_data->{session};

print $q->header(-type => 'text/html', -charset => 'UTF-8');

print <<'HTML';
<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Prueba de check_session</title>

<!-- OSPulso Brand Identity (Favicons) -->
<link rel="icon" type="image/svg+xml" href="../favicon/favicon.svg">
<link rel="icon" type="image/png" sizes="16x16" href="../favicon/favicon-16x16.png">
<link rel="icon" type="image/png" sizes="32x32" href="../favicon/favicon-32x32.png">
<link rel="icon" type="image/png" sizes="64x64" href="../favicon/favicon-64x64.png">
<link rel="icon" type="image/png" sizes="128x128" href="../favicon/favicon-128x128.png">
<link rel="icon" type="image/x-icon" href="../favicon/favicon.ico">
<link rel="apple-touch-icon" sizes="180x180" href="../favicon/apple-touch-icon.png">
<link rel="manifest" href="../favicon/site.webmanifest">
<link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
</head>
<body class="bg-light">
<div class="container mt-5">
  <h2 class="mb-4">Resultado de <code>check_session.pl</code></h2>
  <pre class="bg-white p-3 border rounded">
HTML

# Mostrar todos los valores devueltos
foreach my $key (sort keys %$session_data) {
    my $value = $session_data->{$key} // '';
    $value =~ s/</&lt;/g; $value =~ s/>/&gt;/g;
    print "$key => $value\n";
}

# Mostrar tiempo de expiración si existe
if (defined $session) {
    my $expire = $session->expire() // 'No definido';
    my $now    = scalar localtime();
    print "\nTiempo actual => $now\n";
    print "Expiración configurada => $expire\n";
}

print <<'HTML';
  </pre>
  <div class="mt-4">
    <form method="post" action="cerrar_sesion.pl">
      <button type="submit" class="btn btn-danger">
        <i class="bi bi-box-arrow-right me-1"></i> Cerrar Sesión
      </button>
    </form>
  </div>
</div>
</body>
</html>
HTML
