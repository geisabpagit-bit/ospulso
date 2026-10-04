#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use lib '..';
require 'auth/check_session.pl';

sub render_bottom_nav {
    my ($arg1, @rest) = @_;
    my ($active, %opts);

    # Soporte polimórfico de argumentos: ('agenda') o (role => $role, pagina_actual => 'agenda')
    if (defined $arg1 && ($arg1 eq 'role' || $arg1 eq 'pagina_actual' || $arg1 eq 'active')) {
        my %h = ($arg1, @rest);
        $active = $h{pagina_actual} || $h{active} || '';
        %opts = %h;
    } else {
        $active = $arg1 // '';
        %opts = @rest;
        if (!$active && $opts{pagina_actual}) {
            $active = $opts{pagina_actual};
        }
    }

    my $sd = check_session();
    my $role = $opts{role} || $sd->{role} || 'Invitado';
    my $id_paciente = $opts{id_paciente} || $opts{id} || '';
    my $is_medico = ($role =~ /Medico/i) ? 1 : 0;

    print <<HTML;
    <!-- SDM Premium Bottom Navigation (Dock Edition Estandarizado) -->
    <link rel="stylesheet" href="../css/bottom_nav.css?v=1778173540">
    
    <nav class="sdm-main-bottom-nav d-md-none animate__animated animate__slideInUp">
HTML

    if ($role eq 'Paciente') {
        # Dock del Paciente (5 slots simétricos con FAB central de agendar cita)
        print <<HTML;
        <a href="inicial.pl" class="main-tab-item @{[$active eq 'inicio' ? 'active' : '']}" title="Inicio">
            <i class="bi bi-house-door"></i>
            <span>Inicio</span>
        </a>
        <a href="inbox_paciente.pl" class="main-tab-item @{[$active eq 'inbox_paciente' ? 'active' : '']}" title="Inbox">
            <i class="bi bi-inbox"></i>
            <span>Inbox</span>
        </a>
        <a href="agendar_cita_paciente.pl" class="main-tab-item dock-fab @{[$active eq 'agendar' ? 'active' : '']}" title="Agendar Cita">
            <i class="bi bi-calendar-plus"></i>
            <span>Agendar</span>
        </a>
        <a href="mis_citas.pl" class="main-tab-item @{[$active eq 'mis_citas' ? 'active' : '']}" title="Mis Citas">
            <i class="bi bi-calendar-event"></i>
            <span>Citas</span>
        </a>
        <a href="mis_consultas.pl" class="main-tab-item @{[$active eq 'mis_consultas' ? 'active' : '']}" title="Consultas">
            <i class="bi bi-file-earmark-medical"></i>
            <span>Consultas</span>
        </a>
HTML
    } elsif ($is_medico) {
        # Dock del Médico (5 slots simétricos con gobernanza clínica y FAB contextual)
        my $consulta_url = $id_paciente ? "render_consultas_privado.pl?id=$id_paciente" : "render_consultas.pl";
        
        if ($active eq 'expediente') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="$consulta_url" class="main-tab-item dock-fab active" title="Consulta Médica">
                <i class="bi bi-heart-pulse-fill"></i>
                <span>Consulta</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item active" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
HTML
        } elsif ($active eq 'consulta') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="$consulta_url" class="main-tab-item dock-fab active" title="Consulta Médica">
                <i class="bi bi-heart-pulse-fill"></i>
                <span>Consulta</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
HTML
        } elsif ($active eq 'agenda') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item active" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <button type="button" onclick="abrirModalNuevaCita()" class="main-tab-item dock-fab active" title="Nueva Cita">
                <i class="bi bi-calendar-plus"></i>
                <span>Nueva Cita</span>
            </button>
            <a href="pacientes.pl" class="main-tab-item" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="render_consultas.pl" class="main-tab-item" title="Consulta Médica">
                <i class="bi bi-heart-pulse"></i>
                <span>Consulta</span>
            </a>
HTML
        } elsif ($active eq 'pacientes') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="crud_paciente.pl" class="main-tab-item dock-fab active" title="Nuevo Paciente">
                <i class="bi bi-person-plus-fill"></i>
                <span>Nuevo</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item active" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="render_consultas.pl" class="main-tab-item" title="Consulta Médica">
                <i class="bi bi-heart-pulse"></i>
                <span>Consulta</span>
            </a>
HTML
        } elsif ($active eq 'finanzas' || $active eq 'caja') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item dock-fab active" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="render_consultas.pl" class="main-tab-item" title="Consulta Médica">
                <i class="bi bi-heart-pulse"></i>
                <span>Consulta</span>
            </a>
HTML
        } else {
            # Default Médicos (Dashboard, Ajustes, etc.)
            my $ajustes_active = ($active eq 'ajustes') ? 'active' : '';
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item @{[$active eq 'inicio' ? 'active' : '']}" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item @{[$active eq 'agenda' ? 'active' : '']}" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="render_consultas.pl" class="main-tab-item dock-fab" title="Consulta Médica">
                <i class="bi bi-heart-pulse-fill"></i>
                <span>Consulta</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item @{[$active eq 'pacientes' ? 'active' : '']}" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item @{[$active eq 'finanzas' ? 'active' : '']}" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
HTML
        }
    } else {
        # Dock de Roles Administrativos / Recepción (RBAC: sin consulta médica)
        if ($active eq 'agenda') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item active" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <button type="button" onclick="abrirModalNuevaCita()" class="main-tab-item dock-fab active" title="Nueva Cita">
                <i class="bi bi-calendar-plus"></i>
                <span>Nueva Cita</span>
            </button>
            <a href="pacientes.pl" class="main-tab-item" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
HTML
        } elsif ($active eq 'pacientes' || $active eq 'expediente') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="crud_paciente.pl" class="main-tab-item dock-fab active" title="Nuevo Paciente">
                <i class="bi bi-person-plus-fill"></i>
                <span>Nuevo</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item active" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
HTML
        } elsif ($active eq 'finanzas' || $active eq 'caja') {
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item dock-fab active" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="ajustes.pl" class="main-tab-item" title="Ajustes">
                <i class="bi bi-gear-fill"></i>
                <span>Ajustes</span>
            </a>
HTML
        } else {
            # Default Administrativo (Dashboard, Ajustes, etc.)
            print <<HTML;
            <a href="inicial.pl" class="main-tab-item @{[$active eq 'inicio' ? 'active' : '']}" title="Inicio">
                <i class="bi bi-house-door"></i>
                <span>Inicio</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item @{[$active eq 'agenda' ? 'active' : '']}" title="Citas">
                <i class="bi bi-calendar3"></i>
                <span>Citas</span>
            </a>
            <a href="agenda_main.pl" class="main-tab-item dock-fab" title="Nueva Cita">
                <i class="bi bi-calendar-plus"></i>
                <span>Citas</span>
            </a>
            <a href="pacientes.pl" class="main-tab-item @{[$active eq 'pacientes' ? 'active' : '']}" title="Pacientes">
                <i class="bi bi-people"></i>
                <span>Pacientes</span>
            </a>
            <a href="finanzas.pl" class="main-tab-item @{[$active eq 'finanzas' ? 'active' : '']}" title="Finanzas">
                <i class="bi bi-wallet2"></i>
                <span>Finanzas</span>
            </a>
HTML
        }
    }

    print <<HTML;
    </nav>
HTML
}

1;
