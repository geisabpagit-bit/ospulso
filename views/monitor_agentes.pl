#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use FindBin;
use lib $FindBin::Bin . '/..';
use File::Spec;
use JSON::PP;

require '../auth/check_session.pl';
require '../utils/sub_header.pl';
require '../utils/sub_footer.pl';

# 1. Validación de Seguridad (Capa 4)
my $q = CGI->new;
my $session_data = check_session();
unless ($session_data->{session_ok} && $session_data->{role} eq 'Administrador Global') {
    print $q->redirect('../index.html');
    exit;
}

# 2. Lectura de Logs
my $log_path = File::Spec->catfile($FindBin::Bin, '..', 'logs', 'execution.log');
my @logs;
my $json = JSON::PP->new->utf8;

if (-e $log_path) {
    open(my $fh, '<:encoding(UTF-8)', $log_path);
    while (my $line = <$fh>) {
        chomp $line;
        next unless $line =~ /^\{/;
        eval {
            push @logs, $json->decode($line);
        };
    }
    close($fh);
}
@logs = reverse @logs; # Mostrar más recientes primero

# KPIs Simples
my $total_tasks = scalar @logs;
my $success_count = grep { $_->{status} eq 'SUCCESS' } @logs;
my $error_count = grep { $_->{status} eq 'ERROR' } @logs;

# 3. Render de Cabecera Diamond
render_header(
    usuario => $session_data->{usuario}, 
    titulo => "Observabilidad Agéntica",
    role => $session_data->{role}
);

print <<HTML;
<style>
    .agent-kpi-card {
        background: white;
        border-radius: 24px;
        padding: 25px;
        box-shadow: 0 10px 30px rgba(0,0,0,0.05);
        border: 1px solid rgba(0,0,0,0.03);
        transition: transform 0.3s ease;
    }
    .agent-kpi-card:hover { transform: translateY(-5px); }
    .status-badge {
        padding: 5px 12px;
        border-radius: 10px;
        font-size: 0.7rem;
        font-weight: 800;
        text-transform: uppercase;
    }
    .bg-success-subtle { background: #d1fae5; color: #065f46; }
    .bg-danger-subtle { background: #fee2e2; color: #991b1b; }
    .bg-info-subtle { background: #e0f2fe; color: #075985; }
    
    .log-table th { 
        text-transform: uppercase; 
        font-size: 0.7rem; 
        letter-spacing: 1px; 
        color: #64748b;
        background: #f8fafc;
        padding: 15px;
    }
</style>

<div class="container py-5 animate__animated animate__fadeIn">
    <div class="d-flex justify-content-between align-items-center mb-5">
        <div>
            <h1 class="fw-bold plus-jakarta" style="color: var(--sdm-navy);">Capa 4: Observabilidad</h1>
            <p class="text-muted">Auditoría en tiempo real de la orquestación de agentes Antigravity.</p>
        </div>
        <div class="badge bg-primary-subtle text-primary p-3 rounded-pill fw-bold">
            <i class="bi bi-cpu me-2"></i> AGENTIC OS v4.2.0
        </div>
    </div>

    <!-- KPIs Bento Grid -->
    <div class="row g-4 mb-5">
        <div class="col-md-3">
            <div class="agent-kpi-card">
                <span class="text-muted small fw-bold">EJECUCIONES TOTALES</span>
                <h2 class="fw-bold m-0 mt-2">$total_tasks</h2>
                <i class="bi bi-activity text-primary opacity-25" style="font-size: 2rem; float: right; margin-top: -30px;"></i>
            </div>
        </div>
        <div class="col-md-3">
            <div class="agent-kpi-card">
                <span class="text-muted small fw-bold">ÉXITO OPERATIVO</span>
                <h2 class="fw-bold m-0 mt-2 text-success">@{[$total_tasks ? int(($success_count/$total_tasks)*100) : 0]}%</h2>
                <i class="bi bi-check-circle text-success opacity-25" style="font-size: 2rem; float: right; margin-top: -30px;"></i>
            </div>
        </div>
        <div class="col-md-3">
            <div class="agent-kpi-card">
                <span class="text-muted small fw-bold">ERRORES DETECTADOS</span>
                <h2 class="fw-bold m-0 mt-2 text-danger">$error_count</h2>
                <i class="bi bi-bug text-danger opacity-25" style="font-size: 2rem; float: right; margin-top: -30px;"></i>
            </div>
        </div>
        <div class="col-md-3">
            <div class="agent-kpi-card">
                <span class="text-muted small fw-bold">AGENTE ACTIVO</span>
                <h2 class="fw-bold m-0 mt-2" style="font-size: 1.2rem;">Antigravity Orchestrator</h2>
                <i class="bi bi-robot text-info opacity-25" style="font-size: 2rem; float: right; margin-top: -30px;"></i>
            </div>
        </div>
    </div>

    <!-- Log Table -->
    <div class="agent-kpi-card p-0 overflow-hidden">
        <div class="p-4 border-bottom d-flex justify-content-between align-items-center bg-light">
            <h5 class="fw-bold m-0"><i class="bi bi-journal-text me-2"></i>Historial de Ejecución (Capa 3)</h5>
            <button onclick="location.reload()" class="btn btn-sm btn-white border shadow-sm rounded-pill px-3">
                <i class="bi bi-arrow-clockwise me-2"></i>Actualizar
            </button>
        </div>
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0 log-table">
                <thead>
                    <tr>
                        <th>Timestamp</th>
                        <th>Agente / Rol</th>
                        <th>Tarea / Directriz</th>
                        <th>Estado</th>
                        <th>Recursos / Mensaje</th>
                    </tr>
                </thead>
                <tbody>
HTML

if (@logs) {
    foreach my $log (@logs) {
        my $status_class = $log->{status} eq 'SUCCESS' ? 'bg-success-subtle' : 
                           $log->{status} eq 'ERROR' ? 'bg-danger-subtle' : 'bg-info-subtle';
        
        print <<HTML;
                    <tr>
                        <td class="ps-4 small fw-bold text-muted">$log->{timestamp}</td>
                        <td class="fw-bold">$log->{agent}</td>
                        <td><span class="badge bg-light text-dark border">$log->{task}</span></td>
                        <td><span class="status-badge $status_class">$log->{status}</span></td>
                        <td>
                            <div class="small text-muted">$log->{message}</div>
                            <div class="mt-1" style="font-size: 0.6rem;">
                                <span class="me-2"><i class="bi bi-clock"></i> $log->{resources}->{time}</span>
                                <span><i class="bi bi-cpu"></i> $log->{resources}->{tokens} tokens</span>
                            </div>
                        </td>
                    </tr>
HTML
    }
} else {
    print "<tr><td colspan='5' class='text-center py-5 text-muted'>No hay registros de ejecución disponibles.</td></tr>";
}

print <<HTML;
                </tbody>
            </table>
        </div>
    </div>
</div>
HTML

render_footer();
1;
