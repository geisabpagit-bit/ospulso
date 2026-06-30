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
    
    <nav class="sdm-main-bottom-nav animate__animated animate__slideInUp">
        <a href="inicial.pl" class="main-tab-item @{[$active eq 'inicio' ? 'active' : '']}">
            <i class="bi bi-house-door"></i>
            <span>Inicio</span>
        </a>
        
        @{[ 
            $active eq 'agenda' ? qq(
                <button onclick="abrirModalNuevaCita()" class="main-tab-item">
                    <i class="bi bi-plus-circle-fill text-primary" style="font-size: 2rem;"></i>
                    <span>Nueva Cita</span>
                </button>
                <a href="pacientes.pl" class="main-tab-item">
                    <i class="bi bi-people"></i>
                    <span>Pacientes</span>
                </a>
                <button onclick="abrirModalAjustes()" class="main-tab-item">
                    <i class="bi bi-gear-fill"></i>
                    <span>Ajustes</span>
                </button>
            ) : $active eq 'pacientes' ? qq(
                <a href="crud_paciente.pl" class="main-tab-item">
                    <i class="bi bi-person-plus-fill text-primary" style="font-size: 2rem;"></i>
                    <span>Nuevo</span>
                </a>
                <a href="agenda_main.pl" class="main-tab-item">
                    <i class="bi bi-calendar3"></i>
                    <span>Citas</span>
                </a>
                <a href="ajustes.pl" class="main-tab-item">
                    <i class="bi bi-sliders"></i>
                    <span>Ajustes</span>
                </a>
            ) : qq(
                <a href="agenda_main.pl" class="main-tab-item">
                    <i class="bi bi-calendar3"></i>
                    <span>Citas</span>
                </a>
                <a href="pacientes.pl" class="main-tab-item">
                    <i class="bi bi-people"></i>
                    <span>Pacientes</span>
                </a>
                <a href="ajustes.pl" class="main-tab-item">
                    <i class="bi bi-sliders"></i>
                    <span>Ajustes</span>
                </a>
            )
        ]}
    </nav>
HTML
}
1;
