#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std); # Eliminamos :utf8 global para evitar doble encodificación en JSON
use CGI qw(-utf8);
use JSON::PP qw(encode_json decode_json);
use LWP::UserAgent;
use HTTP::Request;
use File::Basename;
use lib '..';
use utils::db_manager qw(leer_tabla); 

# ==========================================================
# SDM DIGITAL - MOTOR DE AGENDA MODULAR v3.1.0 (GOLD)
# Protocolo: Rutas Absolutas Dinámicas + UTF8 Nativo
# ==========================================================

my $dirname = dirname(__FILE__);
my $ARCHIVO = "$dirname/../dat/citas.dat";
my $CONFIG_FILE = "$dirname/../dat/agenda_config.dat";
my $HEADER  = "id_cita|id_medico|id_paciente|fecha|hora_ini|hora_fin|motivo|notas|estado|event_id";

my $q = CGI->new;
my $accion = $q->param('accion') // '';
my $id_medico = $q->param('id_medico') // '2';

my %CONF = cargar_agenda_config($id_medico);

sub cargar_agenda_config {
    my ($id_m) = @_;
    my %c = (
        laborStart => '08:00', laborEnd => '18:00', 
        lunchStart => '14:00', lunchEnd => '16:00',
        workDays => [1,2,3,4,5], intervalo_minutos => 30,
        festivos => '',        # Unión de ambos (para lógica de bloqueos)
        festivos_global => '', # Solo los del sistema
        festivos_medico => ''  # Solo los del médico
    );

    # 1. Cargar Config Global
    if (-e $CONFIG_FILE) {
        my %g = ();
        _parse_config_file($CONFIG_FILE, \%g);
        $c{festivos_global} = $g{festivos} // '';
        # Copiar valores globales como base
        foreach my $k (keys %g) { $c{$k} = $g{$k} unless $k eq 'festivos'; }
    }

    # 2. Cargar Config Específica del Médico
    my $MED_CONFIG = "$dirname/../dat/agenda_config_medico_$id_m.dat";
    if (-e $MED_CONFIG) {
        my %m = ();
        _parse_config_file($MED_CONFIG, \%m);
        $c{festivos_medico} = $m{festivos} // '';
        
        # Sobrescribir el resto de parámetros (horarios, intervalos, días hábiles)
        foreach my $k (keys %m) {
            next if $k eq 'festivos';
            $c{$k} = $m{$k};
        }
    }
    
    # 3. Mezclar para el Motor de Agenda (Bloqueos en Calendario)
    my @unificados = ();
    push @unificados, split(/,/, $c{festivos_global}) if $c{festivos_global};
    push @unificados, split(/,/, $c{festivos_medico}) if $c{festivos_medico};
    
    my %seen = ();
    my @limpios = grep { $_ && !$seen{$_}++ } map { s/^\s+|\s+$//g; $_ } @unificados;
    $c{festivos} = join(',', @limpios);

    return %c;
}

sub _parse_config_file {
    my ($file, $ref) = @_;
    if (open my $fh, '<:encoding(UTF-8)', $file) {
        while (my $line = <$fh>) {
            chomp $line; $line =~ s/\r//g;
            next if $line =~ /^\s*$/ || $line =~ /^#/;
            my ($key, $val) = split(/=/, $line, 2);
            if ($key eq 'horario_inicio') { $ref->{laborStart} = $val; }
            elsif ($key eq 'horario_fin') { $ref->{laborEnd} = $val; }
            elsif ($key eq 'horario_comida_inicio') { $ref->{lunchStart} = $val; }
            elsif ($key eq 'horario_comida_fin') { $ref->{lunchEnd} = $val; }
            elsif ($key eq 'dias_habiles') { $ref->{workDays} = [ split(/,/, $val) ]; }
            elsif ($key eq 'intervalo_minutos') { $ref->{intervalo_minutos} = $val; }
            elsif ($key eq 'festivos') { $ref->{festivos} = $val; }
        }
        close $fh;
    }
}

# Fase 1: Carga de Datos
my $citas = cargar_citas();

# Fase 2: Enrutamiento de Operaciones
if    ($accion eq 'create')     { crear_cita($citas, $q); }
elsif ($accion eq 'update')     { actualizar_cita($citas, $q); }
elsif ($accion eq 'delete')     { eliminar_cita($citas, $q); }
elsif ($accion eq 'save_config') { guardar_config_medico($q); }
elsif ($accion eq 'get_events') { enviar_eventos_oficial($citas); }

# --- MOTOR DE PERSISTENCIA ---
sub cargar_citas {
    my @lista;
    if (-e $ARCHIVO) {
        if (open my $fh, '<:encoding(UTF-8)', $ARCHIVO) {
            my $cnt = 0;
            while (my $line = <$fh>) {
                $cnt++;
                $line =~ s/\R//g;
                next if $cnt == 1 || $line =~ /^\s*$/;
                my @f = split(/\|/, $line);
                next unless scalar(@f) >= 6;
                foreach (@f) { s/^\s+//; s/\s+$//; }
                push @lista, { 
                    id_cita => $f[0], id_medico => $f[1], id_paciente => $f[2], 
                    fecha => $f[3], hora_ini => $f[4], hora_fin => $f[5], 
                    motivo => $f[6] // '', notas => $f[7] // '', 
                    estado => $f[8] // 'Programada', event_id => $f[9] // '' 
                };
            }
            close $fh;
        }
    }
    return \@lista;
}

sub guardar_citas {
    my ($arr) = @_;
    open my $fh, '>', $ARCHIVO or die "Error Crítico de Escritura: $!";
    binmode $fh, ":utf8";
    print $fh "$HEADER\n";
    foreach my $c (@$arr) {
        print $fh join('|', 
            $c->{id_cita}, $c->{id_medico}, $c->{id_paciente}, $c->{fecha}, 
            $c->{hora_ini}, $c->{hora_fin}, $c->{motivo}, $c->{notas}, 
            $c->{estado}, $c->{event_id}
        ) . "\n";
    }
    close $fh;
}

# --- OPERACIONES CRUD (CON VALIDACIÓN) ---
sub crear_cita {
    my ($arr, $query) = @_;
    my ($fec, $hi, $hf) = ($query->param('fecha'), $query->param('hora_ini'), $query->param('hora_fin'));
    my $id_m = $query->param('id_medico');

    my ($ok_h, $msg_h) = validar_horario($fec, $hi, $hf);
    unless ($ok_h) { responder_json(0, $msg_h); return; }

    my ($ok_c, $msg_c) = detectar_colisiones($arr, $fec, $hi, $hf, $id_m);
    unless ($ok_c) { responder_json(0, $msg_c); return; }

    my $pac_id = $query->param('id_paciente');
    my $pac_nom = obtener_nombre_paciente($pac_id);
    
    # Sincronización protegida con eval para evitar muerte del script
    my $gid = eval { google_sync_event(undef, $id_m, $pac_nom, $fec, $hi, $hf, $query->param('motivo')) };
    if ($@) { log_google("CRITICAL ERROR: $@"); }
    
    push @$arr, { 
        id_cita => time, id_medico => $id_m, id_paciente => $pac_id, 
        fecha => $fec, hora_ini => $hi, hora_fin => $hf, 
        motivo => $query->param('motivo'), notas => '', estado => 'Programada', event_id => $gid // '' 
    };
    
    guardar_citas($arr);
    responder_json(1, "Cita agendada correctamente. " . ($gid ? "(Sincronizada)" : "(Solo Local)"));
}

sub actualizar_cita {
    my ($arr, $query) = @_;
    my $id_c = $query->param('id_cita');
    my ($fec, $hi, $hf) = ($query->param('fecha'), $query->param('hora_ini'), $query->param('hora_fin'));
    my $id_m = $query->param('id_medico');

    my ($ok_h, $msg_h) = validar_horario($fec, $hi, $hf);
    unless ($ok_h) { responder_json(0, $msg_h); return; }

    my ($ok_c, $msg_c) = detectar_colisiones($arr, $fec, $hi, $hf, $id_m, $id_c);
    unless ($ok_c) { responder_json(0, $msg_c); return; }

    my $found = 0;
    foreach my $c (@$arr) {
        if ($c->{id_cita} eq $id_c) {
            my $pac_nom = obtener_nombre_paciente($query->param('id_paciente'));
            my $gid = google_sync_event($c->{event_id}, $id_m, $pac_nom, $fec, $hi, $hf, $query->param('motivo'));
            
            $c->{fecha} = $fec; 
            $c->{hora_ini} = $hi; 
            $c->{hora_fin} = $hf; 
            $c->{motivo} = $query->param('motivo'); 
            $c->{estado} = $query->param('estado') // $c->{estado};
            $c->{event_id} = $gid if $gid;
            $found = 1; last;
        }
    }
    
    if ($found) { guardar_citas($arr); responder_json(1, "Cita actualizada."); }
    else { responder_json(0, "No se encontró el registro."); }
}

sub eliminar_cita {
    my ($arr, $query) = @_;
    my $target = $query->param('id_cita');
    my @filtrados; my $eliminado;
    
    foreach my $c (@$arr) {
        if ($c->{id_cita} eq $target) { $eliminado = $c; }
        else { push @filtrados, $c; }
    }
    
    if ($eliminado) {
        if ($eliminado->{event_id}) { google_delete_event($eliminado->{id_medico}, $eliminado->{event_id}); }
        guardar_citas(\@filtrados);
        responder_json(1, "Registro eliminado correctamente.");
    } else { responder_json(0, "Error: Cita no localizada."); }
}

# --- LÓGICA DE VALIDACIÓN MATEMÁTICA ---
sub validar_horario {
    my ($fec, $hi, $hf) = @_;
    if ($hi ge $hf) { return (0, "La hora de inicio ($hi) debe ser menor a la hora de fin ($hf)."); }
    if ($hi lt $CONF{laborStart} || $hf gt $CONF{laborEnd}) {
        return (0, "Fuera de jornada laboral ($CONF{laborStart} - $CONF{laborEnd}).");
    }
    # Omitir validación de comida si es "Todo el día" o "Resto del día" (termina al final de la jornada)
    if ($hf ne $CONF{laborEnd}) {
        if ($hi lt $CONF{lunchEnd} && $hf gt $CONF{lunchStart}) {
            return (0, "Traslape con horario de comida ($CONF{lunchStart} - $CONF{lunchEnd}).");
        }
    }

    use Time::Piece;
    my $t = eval { Time::Piece->strptime($fec, "%Y-%m-%d") };
    return (0, "Fecha inválida") if $@;
    my $wday = $t->wday; 
    my $iso_wday = ($wday == 1) ? 7 : $wday - 1; 

    my $found_day = 0;
    foreach my $d (@{$CONF{workDays}}) { if ($d == $iso_wday) { $found_day = 1; last; } }
    unless ($found_day) { return (0, "El día seleccionado no es laborable."); }

    # Blindaje de Días Festivos (Personalizados + Globales)
    if ($CONF{festivos}) {
        my @list = split(/,/, $CONF{festivos});
        foreach my $f (@list) {
            $f =~ s/^\s+|\s+$//g;
            if ($f eq $fec) { return (0, "El día seleccionado está marcado como festivo/asueto en tus ajustes."); }
        }
    }
    
    return (1, "OK");
}

sub detectar_colisiones {
    my ($arr, $fec, $hi, $hf, $id_m, $exclude_id) = @_;
    $exclude_id //= '';
    foreach my $c (@$arr) {
        next if $exclude_id && $c->{id_cita} eq $exclude_id;
        next if $c->{fecha} ne $fec;
        next if $c->{id_medico} ne $id_m;
        next if $c->{estado} eq 'Cancelada';
        next if $c->{estado} =~ /Atendida/i; # Excluir citas Atendidas del chequeo de colisión
        if ($hi lt $c->{hora_fin} && $hf gt $c->{hora_ini}) {
            my $pac_nom = obtener_nombre_paciente($c->{id_paciente});
            return (0, "Colisión con: $pac_nom ($c->{hora_ini} - $c->{hora_fin}).");
        }
    }
    return (1, "OK");
}

sub enviar_eventos_oficial {
    my ($arr) = @_;
    my @eventos;
    foreach my $c (@$arr) {
        next if $c->{estado} eq 'Cancelada';
        push @eventos, {
            id => $c->{id_cita},
            title => obtener_nombre_paciente($c->{id_paciente}),
            start => "$c->{fecha}T$c->{hora_ini}:00",
            end => "$c->{fecha}T$c->{hora_fin}:00",
            extendedProps => {
                id_paciente => $c->{id_paciente},
                id_medico => $c->{id_medico},
                motivo => $c->{motivo},
                estado => $c->{estado},
                event_id => $c->{event_id}
            }
        };
    }
    print "Content-Type: application/json; charset=UTF-8\n\n";
    binmode STDOUT, ":raw"; # Aseguramos que los bytes de encode_json pasen directos
    print encode_json({ ok => 1, data => \@eventos, config => \%CONF }); exit;
}

# --- INTEGRACIÓN GOOGLE CALENDAR ---
sub google_sync_event {
    my ($eid, $id_m, $pac, $fec, $ini, $fin, $mot) = @_;
    my $at; eval { $at = obtener_access_token(obtener_refresh_token($id_m)); };
    unless ($at) { log_google("ERROR: No se pudo obtener Access Token para médico $id_m. Posible Refresh Token expirado."); return undef; }
    
    my %ev = ( 
        summary => "SDM: $pac", 
        description => "Motivo: " . ($mot // 'Consulta Dental') . "\nSincronizado desde Software Dental Mexicano", 
        start => { dateTime => "${fec}T${ini}:00-06:00" }, 
        end => { dateTime => "${fec}T${fin}:00-06:00" } 
    );
    
    my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }, timeout => 15);
    my $url = "https://www.googleapis.com/calendar/v3/calendars/primary/events" . ($eid ? "/$eid" : "");
    my $meth = $eid ? 'PUT' : 'POST';
    my $req = HTTP::Request->new($meth => $url);
    $req->header('Authorization' => "Bearer $at", 'Content-Type' => 'application/json');
    $req->content(encode_json(\%ev));
    my $res = $ua->request($req);
    
    if ($res->is_success) {
        log_google("SUCCESS: Evento " . ($eid ? "actualizado" : "creado") . " ($fec $ini)");
        my $data = eval { decode_json($res->decoded_content) };
        return $data ? $data->{id} : undef;
    } else {
        log_google("FAIL: " . $res->status_line . " - " . ($res->decoded_content // 'No content'));
        return undef;
    }
}

sub google_delete_event {
    my ($id_m, $eid) = @_;
    my $at = obtener_access_token(obtener_refresh_token($id_m));
    unless ($at) { log_google("ERROR DELETE: No access token para médico $id_m"); return; }
    my $req = HTTP::Request->new(DELETE => "https://www.googleapis.com/calendar/v3/calendars/primary/events/$eid");
    $req->header('Authorization' => "Bearer $at");
    my $res = LWP::UserAgent->new(ssl_opts=>{verify_hostname=>0}, timeout=>10)->request($req);
    if ($res->is_success) { log_google("SUCCESS DELETE: $eid"); }
    else { log_google("FAIL DELETE: " . $res->status_line . " para evento $eid"); }
}

sub log_google {
    my ($msg) = @_;
    my $log_file = "$dirname/../dat/google_sync.log";
    if (open my $fh, '>>:encoding(UTF-8)', $log_file) {
        my $ts = scalar localtime;
        print $fh "[$ts] $msg\n";
        close $fh;
    }
}

sub guardar_config_medico {
    my ($q) = @_;
    my $id_m = $q->param('id_medico') // return;
    
    my $h_ini = $q->param('h_ini') // '08:00';
    my $h_fin = $q->param('h_fin') // '18:00';
    my $c_ini = $q->param('c_ini') // '14:00';
    my $c_fin = $q->param('c_fin') // '16:00';
    my $d_hab = $q->param('dias')  // '1,2,3,4,5';
    my $int   = $q->param('int')   // '30';

    my $file = "$dirname/../dat/agenda_config_medico_$id_m.dat";
    
    if (open my $fh, '>:encoding(UTF-8)', $file) {
        print $fh "horario_inicio=$h_ini\n";
        print $fh "horario_fin=$h_fin\n";
        print $fh "horario_comida_inicio=$c_ini\n";
        print $fh "horario_comida_fin=$c_fin\n";
        print $fh "intervalo_minutos=$int\n";
        print $fh "dias_habiles=$d_hab\n";
        print $fh "festivos=" . ($q->param('festivos') // '') . "\n";
        close $fh;
        
        # --- Mitigación Mega Regla: Análisis Predictivo de Colisiones Futuras ---
        my $citas = cargar_citas();
        my ($s, $m, $h, $D, $M, $Y) = localtime;
        my $today = sprintf("%04d-%02d-%02d", $Y+1900, $M+1, $D);
        my $warning_msg = "";
        my $afectadas = 0;
        
        my @work_days = split(/,/, $d_hab);
        my @fest = split(/,/, $q->param('festivos') // '');
        
        foreach my $c (@$citas) {
            next if $c->{id_medico} ne $id_m;
            next if $c->{estado} eq 'Cancelada' || $c->{estado} =~ /Atendida/i;
            next if $c->{fecha} lt $today;
            
            my $clash = 0;
            # 1. Fuera de nuevo horario laboral
            if ($c->{hora_ini} lt $h_ini || $c->{hora_fin} gt $h_fin) { $clash = 1; }
            # 2. Traslape con nueva comida (si no es de todo el día)
            if (!$clash && $c->{hora_fin} ne $h_fin) {
                if ($c->{hora_ini} lt $c_fin && $c->{hora_fin} gt $c_ini) { $clash = 1; }
            }
            # 3. Día no laborable
            if (!$clash) {
                use Time::Piece;
                my $t = eval { Time::Piece->strptime($c->{fecha}, "%Y-%m-%d") };
                unless ($@) {
                    my $wday = $t->wday; my $iso_wday = ($wday == 1) ? 7 : $wday - 1;
                    my $found_d = 0;
                    foreach (@work_days) { if ($_ == $iso_wday) { $found_d = 1; last; } }
                    if (!$found_d) { $clash = 1; }
                }
            }
            # 4. Festivos
            if (!$clash) {
                foreach my $f (@fest) { $f =~ s/^\s+|\s+$//g; if ($f eq $c->{fecha}) { $clash = 1; last; } }
            }
            
            if ($clash) { $afectadas++; }
        }
        
        if ($afectadas > 0) {
            $warning_msg = "Existen <strong>$afectadas cita(s) futura(s)</strong> que caen fuera de este nuevo horario o en un día no laborable/festivo recién configurado.<br><br>El sistema ha guardado la configuración, pero se sugiere revisar la agenda mensual y reagendar aquellas citas que visualmente choquen o se salgan del marco de disponibilidad.";
        }

        print $q->header(-type => 'application/json', -charset => 'utf-8');
        print encode_json({ ok => 1, msg => "Configuración guardada correctamente.", warning => $warning_msg });
    } else {
        print $q->header(-type => 'application/json', -charset => 'utf-8');
        print encode_json({ ok => 0, msg => "Error al guardar el archivo de configuración." });
    }
    exit;
}

# --- FIN DE SCRIPT ---

# --- UTILS ---
sub obtener_refresh_token {
    my ($id_m) = @_;
    my $token_file = "$dirname/../dat/tokens_google.dat";
    open my $fh, '<:encoding(UTF-8)', $token_file or return undef;
    <$fh>; # Skip header
    while (<$fh>) { chomp; my ($id, $tk) = split /\|/, $_, 2; return $tk if $id eq $id_m; }
    return undef;
}

sub obtener_access_token {
    my ($rt) = @_;
    unless ($rt) { log_google("ERROR TOKEN: Refresh token vacío para este médico."); return undef; }
    
    my $ua = LWP::UserAgent->new(ssl_opts=>{verify_hostname=>0}, timeout => 15);
    $ua->agent("SoftwareDentalMexicano/3.1");
    
    my $res = $ua->post("https://oauth2.googleapis.com/token", {
        client_id     => "771205596556-64bfspdvs27aqogeot9mdelgvmqm4n7u.apps.googleusercontent.com",
        client_secret => "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",
        refresh_token => $rt, 
        grant_type    => 'refresh_token'
    });
    
    if ($res->is_success) {
        my $data = eval { decode_json($res->decoded_content) };
        return $data ? $data->{access_token} : undef;
    } else {
        log_google("ERROR TOKEN EXCHANGE: " . $res->status_line . " - " . ($res->decoded_content // 'Empty response'));
        return undef;
    }
}

sub obtener_nombre_paciente {
    my ($id) = @_; 
    my $pac_file = "$dirname/../dat/pacientes.dat";
    my $r = leer_tabla($pac_file, '\|');
    foreach my $f (@$r) { return $f->[2] if $f->[0] eq $id; } return "Paciente $id";
}

sub responder_json {
    my ($ok, $msg) = @_;
    print "Content-Type: application/json; charset=UTF-8\n\n";
    binmode STDOUT, ":raw";
    print encode_json({ ok => $ok, msg => $msg }); exit;
}
1;
