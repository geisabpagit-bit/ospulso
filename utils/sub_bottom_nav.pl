#!/usr/bin/perl
use strict;
use warnings;
use utf8;

sub render_bottom_nav {
    my ($active) = @_;
    $active //= '';

    print <<HTML;
    <!-- SDM Premium Bottom Navigation (Item 3.3 Style Guide) -->
    <link rel="stylesheet" href="../css/bottom_nav.css?v=1778173537">
    
    <nav class="sdm-main-bottom-nav d-md-none animate__animated animate__slideInUp">
        <a href="inicial.pl" class="main-tab-item @{[$active eq 'inicio' ? 'active' : '']}" title="Inicio">
            <i class="bi bi-house-door"></i>
            <span>Inicio</span>
        </a>
        
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
    </nav>
HTML
}
1;
