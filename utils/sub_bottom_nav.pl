#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use lib '..';
require 'auth/check_session.pl';

sub render_bottom_nav {
    my ($active) = @_;
    $active //= '';

    my $sd = check_session();
    my $role = $sd->{role} || 'Invitado';

    print <<HTML;
    <!-- SDM Premium Bottom Navigation (Item 3.3 Style Guide) -->
    <link rel="stylesheet" href="../css/bottom_nav.css?v=1778173537">
    
    <nav class="sdm-main-bottom-nav d-md-none animate__animated animate__slideInUp">
        <a href="inicial.pl" class="main-tab-item @{[$active eq 'inicio' ? 'active' : '']}" title="Inicio">
            <i class="bi bi-house-door"></i>
            <span>Inicio</span>
        </a>
HTML

    if ($role eq 'Paciente') {
        print <<HTML;
        <a href="inbox_paciente.pl" class="main-tab-item @{[$active eq 'inbox_paciente' ? 'active' : '']}" title="Inbox">
            <i class="bi bi-inbox"></i>
            <span>Inbox</span>
        </a>
        <!--
        <a href="mis_citas.pl" class="main-tab-item @{[$active eq 'mis_citas' ? 'active' : '']}" title="Mis Citas">
            <i class="bi bi-calendar-event"></i>
            <span>Citas</span>
        </a>
        <button class="main-tab-item dock-fab" title="Agendar Cita" onclick="window.location.href='agendar_cita_paciente.pl'">
            <i class="bi bi-calendar-plus"></i>
            <span>Agendar</span>
        </button>
        <a href="mi_expediente.pl" class="main-tab-item @{[$active eq 'mi_historial' ? 'active' : '']}" title="Mi Historial">
            <i class="bi bi-file-medical"></i>
            <span>Historial</span>
        </a>
        -->
HTML
    } else {
        print <<HTML;
        @{[ 
            $active eq 'agenda' ? qq(
                <a href="pacientes.pl" class="main-tab-item" title="Pacientes">
                    <i class="bi bi-people"></i>
                    <span>Pacientes</span>
                </a>
                <button onclick="abrirModalNuevaCita()" class="main-tab-item dock-fab" title="Nueva Cita">
                    <i class="bi bi-calendar-plus"></i>
                    <span>Nueva Cita</span>
                </button>
                <a href="render_consultas.pl" class="main-tab-item" title="Consulta">
                    <i class="bi bi-heart-pulse"></i>
                    <span>Consulta</span>
                </a>
            ) : $active eq 'pacientes' ? qq(
                <a href="agenda_main.pl" class="main-tab-item" title="Citas">
                    <i class="bi bi-calendar3"></i>
                    <span>Citas</span>
                </a>
                <a href="crud_paciente.pl" class="main-tab-item dock-fab" title="Nuevo Paciente">
                    <i class="bi bi-person-plus-fill"></i>
                    <span>Nuevo</span>
                </a>
                <a href="render_consultas.pl" class="main-tab-item" title="Consulta">
                    <i class="bi bi-heart-pulse"></i>
                    <span>Consulta</span>
                </a>
            ) : qq(
                <a href="agenda_main.pl" class="main-tab-item @{[$active eq 'agenda' ? 'active' : '']}" title="Citas">
                    <i class="bi bi-calendar3"></i>
                    <span>Citas</span>
                </a>
                <a href="pacientes.pl" class="main-tab-item @{[$active eq 'pacientes' ? 'active' : '']}" title="Pacientes">
                    <i class="bi bi-people"></i>
                    <span>Pacientes</span>
                </a>
                <a href="render_consultas.pl" class="main-tab-item @{[$active eq 'consulta' ? 'active' : '']}" title="Consulta">
                    <i class="bi bi-heart-pulse"></i>
                    <span>Consulta</span>
                </a>
            )
        ]}
HTML
    }
    
    print <<HTML;
    </nav>
HTML
}
1;
