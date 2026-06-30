#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
use open qw(:std :utf8);
use CGI;
use CGI::Session;
use CGI::Carp qw(fatalsToBrowser);
use JSON qw(decode_json encode_json);
use lib '..';
use FindBin;
use File::Spec;

# --- CONFIGURACIÃ“N DE RUTAS ABSOLUTAS ---
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
use utils::db_manager qw(leer_tabla);

my $q = CGI->new;
my $session_data = check_session();

# Redireccionar si no hay sesiÃ³n
if (!$session_data->{session_ok}) {
    print $q->redirect(-url => '../index.pl');
    exit;
}

my $id_target = $q->param('id') || '';

my $PACIENTES_FILE = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'pacientes.dat');
my $ESTUDIOS_FILE  = File::Spec->catfile($FindBin::Bin, '..', 'dat', 'estudios.dat');

my $pacientes_ref = leer_tabla($PACIENTES_FILE, '\|');
my $estudios_ref  = leer_tabla($ESTUDIOS_FILE, '\|');

my $paciente_info = {
    id_paciente => $id_target,
    nombre      => 'Desconocido',
    f_nac       => '-',
    sexo        => '-',
};

foreach my $p (@$pacientes_ref) {
    if ($p->[0] eq $id_target) {
        $paciente_info->{nombre} = $p->[2] || 'Desconocido';
        $paciente_info->{f_nac}  = $p->[6] || '-';
        $paciente_info->{sexo}   = $p->[7] || '-';
        last;
    }
}

my $est_modalidad = '-';
my $est_fecha     = '-';
my $est_desc      = 'Sin descripciÃ³n';

my $paciente = {
    id_paciente => $paciente_info->{id_paciente},
    nombre      => $paciente_info->{nombre},
    f_nac       => $paciente_info->{f_nac},
    sexo        => $paciente_info->{sexo},
    modalidad   => $est_modalidad,
    fecha_est   => $est_fecha,
    descripcion => $est_desc
};

print $q->header(-type => 'text/html', -charset => 'UTF-8');

print <<HTML;
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>SDM Viewer Pro - Paciente: $paciente->{nombre}</title>
    
    <!-- Bootstrap 5 -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap\@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Bootstrap Icons -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons\@1.11.1/font/bootstrap-icons.css">
    <!-- Google Fonts -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght\@400;500;600;700;800&display=swap" rel="stylesheet">
    
    <!-- MedentOs Master CSS -->
    <link rel="stylesheet" href="../css/medentia_master.css?v=$^T">
    <!-- Visor MÃ©dico Estructural CSS -->
    <link rel="stylesheet" href="../css/visor_medico.css?v=$^T">
    
    <!-- Librerias Medicas (Cornerstone Legacy para SPA) -->
    <script src="https://unpkg.com/cornerstone-core@2.3.0/dist/cornerstone.js"></script>
    <script src="https://unpkg.com/cornerstone-math@0.1.9/dist/cornerstoneMath.js"></script>
    <script src="https://unpkg.com/cornerstone-tools@6.0.8/dist/cornerstoneTools.js"></script>
    <script src="https://unpkg.com/dicom-parser@1.8.13/dist/dicomParser.js"></script>
    <script src="https://unpkg.com/cornerstone-wado-image-loader@4.1.5/dist/cornerstoneWADOImageLoader.bundle.min.js"></script>
    <script src="https://unpkg.com/cornerstone-web-image-loader@2.1.1/dist/cornerstoneWebImageLoader.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
</head>
<body class="visor-mode">

    <div class="visor-layout">
        <!-- HEADER / NAVBAR -->
        <header class="visor-header bg-medentia-gradient">
            <div class="d-flex align-items-center gap-2">
                <button class="tool-btn border-0 shadow-none" onclick="VisorApp.toggleSidebar('left')" title="Mostrar/Ocultar Estudios">
                    <i class="bi bi-layout-sidebar"></i>
                </button>
            </div>
            <!-- TOOLBAR INYECTADA EN EL NAVBAR -->
            <div class="visor-toolbar d-flex align-items-center flex-grow-1 justify-content-center" style="overflow-x: auto;">
                <input type="file" id="file-input" style="display:none;" accept="image/*,.dcm">
                
                <!-- Grupo 1: Archivo -->
                <div class="d-flex bg-white bg-opacity-10 rounded-3 p-1 mx-1 mx-md-2">
                    <button class="tool-btn" title="Nuevo Estudio" data-bs-toggle="modal" data-bs-target="#modalNuevoEstudio" id="btn-nuevo-estudio"><i class="bi bi-folder-plus"></i></button>
                    <button class="tool-btn" title="Abrir Archivo" id="btn-open-file"><i class="bi bi-folder2-open"></i></button>
                    <button class="tool-btn" title="Exportar" id="btn-export"><i class="bi bi-box-arrow-up"></i></button>
                    <button class="tool-btn" title="Imprimir" id="btn-print"><i class="bi bi-printer"></i></button>
                </div>
                
                <!-- Grupo 2: Navegaci&oacute;n -->
                <div class="d-flex bg-white bg-opacity-10 rounded-3 p-1 mx-1 mx-md-2">
                    <button class="tool-btn" title="Seleccionar" data-action="select"><i class="bi bi-cursor"></i></button>
                    <button class="tool-btn active" title="Pan" data-action="pan"><i class="bi bi-arrows-move"></i></button>
                    <button class="tool-btn" title="Zoom In" data-action="zoom-in"><i class="bi bi-zoom-in"></i></button>
                    <button class="tool-btn" title="Zoom Out" data-action="zoom-out"><i class="bi bi-zoom-out"></i></button>
                </div>

                <!-- Grupo 3: Anotaciones -->
                <div class="d-flex bg-white bg-opacity-10 rounded-3 p-1 mx-1 mx-md-2">
                    <button class="tool-btn" title="Medir" data-tool="medir"><i class="bi bi-rulers"></i></button>
                    <button class="tool-btn" title="&Aacute;ngulo" data-tool="angulo"><i class="bi bi-triangle-half"></i></button>
                    <button class="tool-btn" title="ROI" data-tool="roi"><i class="bi bi-bounding-box-circles"></i></button>
                    <button class="tool-btn" title="Texto" data-tool="texto"><i class="bi bi-cursor-text"></i></button>
                    <button class="tool-btn" title="Pol&iacute;gono" data-tool="poligono"><i class="bi bi-pentagon"></i></button>
                    <button class="tool-btn" title="Borrar Anotaci&oacute;n" data-tool="borrar"><i class="bi bi-eraser"></i></button>
                </div>

                <!-- Grupo 4: Transformaci&oacute;n -->
                <div class="d-flex bg-white bg-opacity-10 rounded-3 p-1 mx-1 mx-md-2">
                    <button class="tool-btn" title="Rotar Izq" data-action="rotate-left"><i class="bi bi-arrow-counterclockwise"></i></button>
                    <button class="tool-btn" title="Rotar Der" data-action="rotate-right"><i class="bi bi-arrow-clockwise"></i></button>
                    <button class="tool-btn d-none d-md-flex" title="Flip V" data-action="flip-v"><i class="bi bi-symmetry-horizontal"></i></button>
                    <button class="tool-btn d-none d-md-flex" title="Flip H" data-action="flip-h"><i class="bi bi-arrows-expand"></i></button>
                    <button class="tool-btn ms-2" title="Restablecer" data-action="reset"><i class="bi bi-arrow-repeat"></i></button>
                </div>
            </div>

            <div class="d-flex align-items-center gap-3 ms-auto" style="font-family: 'Inter', sans-serif;">
                <div class="text-end d-none d-sm-block">
                    <div class="fw-bold small lh-1">$session_data->{usuario}</div>
                    <div class="text-white-50" style="font-size: 0.65rem;">$session_data->{role}</div>
                </div>
                <div class="bg-white text-primary rounded-circle d-flex align-items-center justify-content-center shadow-sm" style="width: 35px; height: 35px;">
                    <i class="bi bi-person fw-bold"></i>
                </div>
                <button class="tool-btn border-0 shadow-none" onclick="VisorApp.toggleSidebar('right')" title="Mostrar/Ocultar Herramientas">
                    <i class="bi bi-layout-sidebar-reverse"></i>
                </button>
            </div>
        </header>

        <!-- MAIN BODY -->
        <div class="visor-body">
            
            <!-- LEFT SIDEBAR: ESTUDIOS & SERIES -->
            <aside class="visor-sidebar-left">
                <!-- Toggle Info Paciente -->
                <div class="p-3 border-bottom">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <div class="d-flex align-items-center gap-2">
                            <div class="bg-primary text-white rounded-circle d-flex align-items-center justify-content-center" style="width: 32px; height: 32px;">
                                <i class="bi bi-person"></i>
                            </div>
                            <div>
                                <div class="fw-bold text-dark lh-1" style="font-size: 0.85rem;">$paciente->{nombre}</div>
                                <div class="text-muted small">ID: $paciente->{id_paciente}</div>
                            </div>
                        </div>
                        <button class="btn btn-sm btn-link text-decoration-none p-0" type="button" data-bs-toggle="collapse" data-bs-target="#collapsePatientInfo">
                            <i class="bi bi-chevron-down text-muted"></i>
                        </button>
                    </div>
                    <div class="collapse" id="collapsePatientInfo">
                        <div class="card-medentia p-2 mt-2 small bg-white shadow-sm border-0 rounded-3">
                            <table class="table table-sm table-borderless m-0">
                                <tr><td class="text-muted py-0">Nac:</td><td class="fw-bold text-end text-dark py-0">$paciente->{f_nac}</td></tr>
                                <tr><td class="text-muted py-0">Sexo:</td><td class="fw-bold text-end text-dark py-0">$paciente->{sexo}</td></tr>
                            </table>
                        </div>
                    </div>
                </div>

                <!-- Buscador Avanzado -->
                <div class="p-3 border-bottom sticky-top" style="background-color: var(--md-aqua-soft, #f0fdfa);">
                    <div class="d-flex justify-content-between align-items-center mb-2">
                        <h6 class="fw-black text-primary m-0 text-uppercase" style="font-size: 0.8rem;">ESTUDIOS</h6>
                        <button class="btn btn-sm btn-link text-decoration-none p-0" data-bs-toggle="modal" data-bs-target="#modalBusquedaAvanzada"><i class="bi bi-sliders me-1"></i>Filtros</button>
                    </div>
                    <div class="input-group input-group-sm shadow-sm rounded-2">
                        <span class="input-group-text bg-white border-end-0"><i class="bi bi-search text-muted"></i></span>
                        <input type="text" class="form-control bg-white border-start-0 ps-0" placeholder="Buscar estudios..." id="search-estudios" list="lista-estudios">
                        <datalist id="lista-estudios"></datalist>
                    </div>
                </div>
                
                <!-- Contenedor para inyecciÃ³n dinÃ¡mica de JavaScript (Series) -->
                <div id="series-container-dynamic" class="p-3 d-flex flex-column gap-2 flex-grow-1 overflow-auto">
                    <div class="p-5 text-center text-muted small" id="series-spinner">
                        <div class="spinner-border text-primary spinner-border-sm mb-2"></div><br>
                        Sincronizando PACS...
                    </div>
                </div>
            </aside>

            <!-- MAIN CANVAS AREA -->
            <main class="visor-main">
                <!-- Canvas Container -->
                <div class="canvas-container" id="dicomImage">
                    <!-- Overlay Text Top Left -->
                    <div class="dicom-overlay top-left" id="overlay-tl">
                        <div class="fw-bold">$paciente->{nombre}</div>
                        <div>ID: $paciente->{id_paciente}</div>
                        <div>$paciente->{f_nac} $paciente->{sexo}</div>
                        <div id="overlay-tl-date">$paciente->{fecha_est}</div>
                        <div id="overlay-tl-time"></div>
                    </div>
                    <!-- Overlay Text Top Right -->
                    <div class="dicom-overlay top-right" id="overlay-tr">
                        <div class="fw-bold" id="overlay-tr-desc">$paciente->{descripcion}</div>
                        <div id="overlay-tr-serie">Serie: 1</div>
                        <div id="overlay-tr-image">Imagen: 1/1</div>
                    </div>
                    <!-- Overlay Text Bottom Left -->
                    <div class="dicom-overlay bottom-left" id="overlay-bl">
                        <div id="overlay-bl-wlww">WL: -- WW: --</div>
                        <div id="overlay-bl-thickness"></div>
                    </div>
                    <!-- Overlay Text Bottom Right -->
                    <div class="dicom-overlay bottom-right" id="overlay-br">
                        <div id="overlay-br-dim">-- x --</div>
                        <div id="overlay-br-zoom">Zoom: --</div>
                        <div id="overlay-br-modality">$paciente->{modalidad}</div>
                    </div>

                    <!-- Contenedor Cornerstone -->
                    <div id="dicomImage" style="width: 100%; height: 100%; position: absolute; top: 0; left: 0; bottom: 0; right: 0;"></div>
                    
                    <!-- Spinner de Carga Central -->
                    <div id="dicomLoading" class="position-absolute d-none text-white text-center" style="top: 50%; left: 50%; transform: translate(-50%, -50%); z-index: 10;">
                        <div class="spinner-border text-light mb-2" role="status" style="width: 3rem; height: 3rem;"></div>
                        <div class="fw-bold">Cargando Estudio...</div>
                    </div>
                    
                    <!-- Ejes de orientaciÃ³n mÃ©dicos -->
                    <div class="position-absolute text-white-50 small fw-bold" style="left: 15px; top: 50%; transform: translateY(-50%);">R</div>
                    <div class="position-absolute text-white-50 small fw-bold" style="right: 15px; top: 50%; transform: translateY(-50%);">L</div>
                    <div class="position-absolute text-white-50 small fw-bold" style="top: 15px; left: 50%; transform: translateX(-50%);">A</div>
                    <div class="position-absolute text-white-50 small fw-bold" style="bottom: 15px; left: 50%; transform: translateX(-50%);">P</div>
                </div>

            </main>

            <!-- RIGHT SIDEBAR: INFO & HERRAMIENTAS -->
            <aside class="visor-sidebar-right">
                <!-- Calibradores de Escala DICOM -->
                <!-- Galería de Series (Thumbnails) -->
                <div class="p-3 border-bottom" id="dicom-series">
                    <h6 class="fw-black text-info mb-3 text-uppercase" style="font-size: 0.75rem; letter-spacing: 1px;">Series de Imagen</h6>
                    <div class="d-flex align-items-center">
                        <button class="btn btn-sm btn-outline-secondary me-2 flex-shrink-0" id="btn-scroll-left" style="height: 60px;"><i class="bi bi-chevron-left"></i></button>
                        <div class="d-flex flex-nowrap overflow-auto flex-grow-1 series-nav-horizontal" id="series-thumbnails-container" style="scroll-behavior: smooth; scrollbar-width: none;">
                        </div>
                        <button class="btn btn-sm btn-outline-secondary ms-2 flex-shrink-0" id="btn-scroll-right" style="height: 60px;"><i class="bi bi-chevron-right"></i></button>
                    </div>
                </div>

                <!-- Calibradores de Escala DICOM -->
                <div class="p-3 border-bottom" id="dicom-calibradores">
                    <div class="row g-2 mb-2">
                        <div class="col-4 text-center">
                            <div class="small fw-bold text-muted mb-1"><i class="bi bi-zoom-in"></i> Zoom</div>
                            <input type="range" class="medentia-slider w-100" min="10" max="300" value="100" id="slider-zoom">
                            <div class="small text-primary fw-bold" id="label-zoom">100%</div>
                        </div>
                        <div class="col-4 text-center">
                            <div class="small fw-bold text-muted mb-1"><i class="bi bi-circle-half"></i> Contraste</div>
                            <input type="range" class="medentia-slider w-100" min="0" max="500" value="100" id="slider-ww">
                            <div class="small text-primary fw-bold" id="label-ww">100%</div>
                        </div>
                        <div class="col-4 text-center">
                            <div class="small fw-bold text-muted mb-1"><i class="bi bi-brightness-high"></i> Brillo</div>
                            <input type="range" class="medentia-slider w-100" min="0" max="500" value="100" id="slider-wl">
                            <div class="small text-primary fw-bold" id="label-wl">100%</div>
                        </div>
                    </div>
                    <button class="btn btn-outline-primary w-100 btn-sm fw-bold shadow-sm" id="btn-reset-sliders" title="Restablecer Calibradores" data-bs-toggle="tooltip">
                        <i class="bi bi-arrow-counterclockwise me-1"></i>Restablecer Calibradores
                    </button>
                </div>

                <!-- Filtros y Presets -->
                <div class="p-3 border-bottom" id="dicom-presets">
                    <h6 class="fw-black text-info mb-3 text-uppercase" style="font-size: 0.75rem; letter-spacing: 1px;">Filtros (Presets)</h6>
                    <div class="d-grid" style="grid-template-columns: repeat(5, 1fr); gap: 0.5rem;">
                        <button class="preset-btn btn btn-outline-secondary btn-sm fw-bold p-1" data-preset="normal" title="Normal" data-bs-toggle="tooltip"><i class="bi bi-circle-half fs-6"></i></button>
                        <button class="preset-btn btn btn-outline-secondary btn-sm fw-bold p-1" data-preset="invert" title="Invertir" data-bs-toggle="tooltip"><i class="bi bi-circle fs-6"></i></button>
                        <button class="preset-btn btn btn-outline-secondary btn-sm fw-bold p-1" data-preset="bone" title="Hueso" data-bs-toggle="tooltip"><i class="bi bi-person-bounding-box fs-6"></i></button>
                        <button class="preset-btn btn btn-outline-secondary btn-sm fw-bold p-1" data-preset="bw" title="B/N" data-bs-toggle="tooltip"><i class="bi bi-moon-stars fs-6"></i></button>
                        <button class="preset-btn btn btn-outline-danger btn-sm fw-bold p-1" data-preset="reset" title="Reset" data-bs-toggle="tooltip"><i class="bi bi-arrow-counterclockwise fs-6"></i></button>
                    </div>
                </div>

                <!-- Capas / Anotaciones -->
                <div class="p-3 d-flex flex-column" style="flex: 1 1 0%; min-height: 0;">
                    <h6 class="fw-black text-info mb-3 text-uppercase flex-shrink-0" style="font-size: 0.75rem; letter-spacing: 1px;">Capas / Anotaciones</h6>
                    <div class="list-group list-group-flush mb-3 small overflow-y-auto flex-grow-1" id="capas-list" style="min-height: 0;">
                    </div>
                </div>
            </aside>
        </div>

        <!-- MOBILE BOTTOM NAVIGATION -->
        <nav class="visor-mobile-nav">
            <div class="mobile-nav-btn active">
                <i class="bi bi-grid"></i>
                <span>Im&aacute;genes</span>
            </div>
            <div class="mobile-nav-btn">
                <i class="bi bi-folder-symlink"></i>
                <span>Estudios</span>
            </div>
            <div class="mobile-nav-btn">
                <i class="bi bi-layers"></i>
                <span>Capas</span>
            </div>
            <div class="mobile-nav-btn">
                <i class="bi bi-tools"></i>
                <span>Herram.</span>
            </div>
        </nav>

        <!-- FOOTER BAR -->
        <footer class="visor-footer">
            <div class="d-flex align-items-center gap-2">
                <div style="width: 8px; height: 8px; border-radius: 50%; background: #10b981;"></div>
                <span class="fw-bold text-dark">Conectado al servidor</span>
                <span class="ms-2">v1.0.0</span>
            </div>
            <div class="d-flex align-items-center gap-3">
                <div class="d-flex align-items-center gap-2">
                    <span>Almacenamiento:</span>
                    <div class="progress" style="width: 150px; height: 6px; border-radius: 4px;">
                        <div class="progress-bar bg-primary" role="progressbar" style="width: 45%;"></div>
                    </div>
                    <span class="fw-bold text-dark">45% (9.1 GB / 20 GB)</span>
                </div>
                <div class="vr bg-secondary"></div>
                <button class="btn btn-sm text-primary fw-bold p-0"><i class="bi bi-journal-code me-1"></i>Logs</button>
            </div>
        </footer>
    </div>

    <!-- Modal Nuevo Estudio -->
    <div class="modal fade" id="modalNuevoEstudio" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content rounded-5 border-0 shadow-lg">
                <div class="modal-header border-0 pb-0">
                    <h5 class="fw-black text-dark"><i class="bi bi-folder-plus text-info me-2"></i>Crear Nuevo Estudio</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body p-4">
                    <form id="form-nuevo-estudio">
                        <div class="mb-3">
                            <label class="small fw-bold text-muted mb-2">Modalidad</label>
                            <select class="form-select rounded-4 py-3 bg-light border-0 fw-bold" id="nuevoModalidad">
                                <option value="CT">Tomograf&iacute;a (CT)</option>
                                <option value="MRI">Resonancia (MR)</option>
                                <option value="RX">Radiograf&iacute;a (XR)</option>
                                <option value="US">Ultrasonido (US)</option>
                                <option value="OT">Otro / Fotograf&iacute;a</option>
                            </select>
                        </div>
                        <div class="mb-4">
                              <label class="small fw-bold text-muted mb-2">Descripci&oacute;n</label>
                              <input type="text" class="form-control rounded-4 py-3 bg-light border-0" id="nuevoDesc" required placeholder="Ej: Cr&aacute;neo Simple">
                        </div>
                        <button type="submit" class="btn btn-info text-white w-100 rounded-pill py-3 fw-bold shadow-sm" id="btn-submit-nuevo">
                            Crear Estudio <i class="bi bi-plus-circle ms-1"></i>
                        </button>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <!-- Modal BÃºsqueda Avanzada -->
    <div class="modal fade" id="modalBusquedaAvanzada" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered">
            <div class="modal-content border-0 shadow-lg">
                <div class="modal-header bg-light border-bottom-0">
                    <h6 class="modal-title fw-black text-primary"><i class="bi bi-sliders me-2"></i>BÃºsqueda Avanzada de Estudios</h6>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <div class="row g-3">
                        <div class="col-md-12">
                            <label class="form-label small fw-bold text-muted">Estudio / DescripciÃ³n</label>
                            <input type="text" class="form-control form-control-sm" id="filter-nombre" placeholder="Palabra clave...">
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small fw-bold text-muted">Modalidad</label>
                            <select class="form-select form-select-sm" id="filter-modalidad">
                                <option value="">Todas</option>
                                <option value="RX">Rayos X (RX)</option>
                                <option value="CT">TomografÃ­a (CT)</option>
                                <option value="MRI">Resonancia (MRI)</option>
                                <option value="US">Ultrasonido (US)</option>
                                <option value="OT">Otros</option>
                            </select>
                        </div>
                        <div class="col-md-6">
                            <label class="form-label small fw-bold text-muted">Fecha Exacta</label>
                            <input type="date" class="form-control form-control-sm" id="filter-fecha">
                        </div>
                    </div>
                </div>
                <div class="modal-footer border-top-0 bg-light">
                    <button type="button" class="btn btn-sm btn-secondary" id="btn-reset-filtros">Limpiar</button>
                    <button type="button" class="btn btn-sm btn-primary fw-bold" data-bs-dismiss="modal" id="btn-aplicar-filtros">Aplicar Filtros</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Plantilla de Impresi&oacute;n -->
    <div id="print-template" class="d-none">
        <div class="print-header">
            <h2 class="mb-1">Hospital Software Dental Mexicano</h2>
            <p class="mb-0"><strong>M&oacute;dulo:</strong> Visor M&eacute;dico Radiol&oacute;gico</p>
            <p class="mb-0"><strong>Fecha de Impresi&oacute;n:</strong> <span id="print-date"></span></p>
        </div>
        <hr style="border-color: #000; opacity: 1;">
        
        <div class="print-body text-center my-4">
              <h4 class="mb-3 text-start">Paciente: $paciente->{nombre} (ID: $paciente->{id_paciente})</h4>
              <img id="print-image-container" src="" style="width: 100%; max-height: 55vh; display: block; object-fit: contain; border: 2px solid #333;" alt="Renderizado M&eacute;dico" />
              
              <!-- Reporte de Anotaciones -->
              <div id="print-annotations" class="mt-4 text-start"></div>
          </div>
        
        <hr style="border-color: #000; opacity: 1;">
        <div class="print-footer small">
            <p class="mb-1"><strong>Direcci&oacute;n:</strong> Av. Principal 123, Ciudad de M&eacute;xico</p>
            <p class="mb-1"><strong>Tel&eacute;fono:</strong> (55) 1234-5678 | <strong>Correo:</strong> contacto\@sdm.com</p>
            <p class="mb-1 mt-2 fst-italic"><strong>Aviso de confidencialidad:</strong> Este documento contiene informaci&oacute;n confidencial destinada &uacute;nicamente al receptor autorizado.</p>
            <p class="mb-0 mt-3 text-end"><strong>C&oacute;digo interno:</strong> RX-001 | <strong>P&aacute;gina 1 de 1</strong></p>
        </div>
    </div>

    <!-- Bootstrap JS Bundle -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <!-- SweetAlert2 para validaciones / UI -->
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
    <!-- HTML2Canvas para Exportar / Imprimir -->
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
    
    <!-- Cornerstone.js Dependencies -->
    <script src="https://unpkg.com/hammerjs@2.0.8/hammer.min.js"></script>
    <script src="https://unpkg.com/dicom-parser@1.8.21/dist/dicomParser.min.js"></script>
    <script src="https://unpkg.com/cornerstone-core@2.6.1/dist/cornerstone.min.js"></script>
    <script src="https://unpkg.com/cornerstone-math@0.1.10/dist/cornerstoneMath.min.js"></script>
    <script src="https://unpkg.com/cornerstone-tools@6.0.8/dist/cornerstoneTools.min.js"></script>
    <script src="https://unpkg.com/cornerstone-wado-image-loader@4.13.2/dist/cornerstoneWADOImageLoader.min.js"></script>
    <script src="https://unpkg.com/cornerstone-web-image-loader@2.1.1/dist/cornerstoneWebImageLoader.min.js"></script>
    
    <script>
        // DeclaraciÃ³n Global para el Controlador JS
        window.ID_PACIENTE = '$paciente->{id_paciente}';
    </script>
    
    <!-- Controlador Principal del Visor MÃ©dico -->
    <script src="../js/visor_medico_spa.js?v=$^T"></script>
</body>
</html>
HTML

