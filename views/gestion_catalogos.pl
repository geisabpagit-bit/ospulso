#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use utf8;
binmode STDOUT, ":utf8";
use CGI;
use FindBin;
use File::Spec;
use lib $FindBin::Bin . '/..';
require "$FindBin::Bin/../auth/check_session.pl";
require "$FindBin::Bin/../utils/sub_header.pl";
require "$FindBin::Bin/../utils/sub_sidebar.pl";


my $q = CGI->new;
my $session_data = check_session();

if (!$session_data->{session_ok} || $session_data->{role} ne 'Administrador Organizacion') {
    print $q->redirect(-uri => '../index.html');
    exit;
}

my $usuario = $session_data->{usuario};
my $role = $session_data->{role};
my $id_medico = $session_data->{id_usuario} || '';
my $id_empresa = $session_data->{id_empresa} || '';
my $nombre_completo = $session_data->{nombre_completo} || $usuario;

my $org_clues = '';
if ($id_empresa eq '0') {
    $org_clues = 'QTSMP000116';
} else {
    my $dat_dir = File::Spec->catdir($FindBin::Bin, '..', 'dat');
    my $n_file = File::Spec->catfile($dat_dir, 'negocios.dat');
    if (-e $n_file && open(my $nf, '<:encoding(UTF-8)', $n_file)) {
        <$nf>;
        while (my $line = <$nf>) {
            chomp $line; my @f = split(/\|/, $line, -1);
            if ($f[0] eq $id_empresa) { $org_clues = $f[18] // ''; last; }
        }
        close $nf;
    }
}

if (!$org_clues) {
    print $q->redirect(-uri => 'inicial.pl');
    exit;
}

render_header(
    titulo => 'Gestión de Catálogos (CRUD) - OSPulso',
    role  => $role,
    usuario => $usuario
);

print <<'HTML';
<!-- DataTables CSS -->
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css">
<!-- Select2 CSS (Tema Bootstrap 5) -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/css/select2.min.css" />
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/select2-bootstrap-5-theme@1.3.0/dist/select2-bootstrap-5-theme.min.css" />
<!-- SDM Mobile Standards -->
<link rel="stylesheet" href="../css/sdm_mobile_standards.css">

<!-- DataTables JS (necesario antes de su uso) -->
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<!-- Select2 JS -->
<script src="https://cdn.jsdelivr.net/npm/select2@4.1.0-rc.0/dist/js/select2.min.js"></script>
<style>
    /* Estilos específicos de la vista */
    .catalog-wrapper { padding: 20px; }
    #table-container { min-height: 300px; }
    .table-container th { white-space: nowrap; }
    #dynamic-form-fields .form-group { margin-bottom: 1rem; }
</style>
<div id="wrapper">
HTML

utils::sub_sidebar::render_sidebar(
    usuario => $usuario,
    role => $role,
    id_medico => $id_medico,
    id_empresa => $id_empresa,
    pagina_actual => 'gestion_catalogos'
);

print <<"HTML";
    <div id="content-wrapper" class="d-flex flex-column">
        <div id="content">
            <!-- Topbar placeholder si es necesario, asumimos integrado en sub_header o custom -->
            
            <div class="container-mobile-flush catalog-wrapper">
                
                <div class="alert alert-danger shadow-sm border-danger border-2 rounded-4 mb-4" role="alert">
                    <h4 class="alert-heading text-danger fw-bold"><i class="bi bi-exclamation-triangle-fill me-2"></i> Zona de Alto Riesgo - Modificación Directa de Base de Datos</h4>
                    <p class="mb-0">Usted está accediendo a los catálogos en crudo correspondientes a su Tenant (<strong>$org_clues</strong>). Las modificaciones y eliminaciones aquí son inmediatas y definitivas. <strong>ADVERTENCIA:</strong> Cambiar o eliminar un ID (Columna 0) que ya fue usado históricamente en finanzas o pacientes, romperá la integridad de la base de datos de manera irreversible.</p>
                </div>

                <div class="card card-mobile-flush shadow-sm border-0 rounded-4 mb-4">
                    <div class="card-header bg-white py-3 d-flex flex-column flex-md-row align-items-center justify-content-between border-0 rounded-top-4">
                        <h5 class="m-0 fw-bold" style="color: var(--md-blue-deep);"><i class="bi bi-database-gear me-2 text-primary"></i> Gestión Dinámica de Catálogos</h5>
                        
                        <div class="d-flex align-items-center mt-3 mt-md-0 w-100 w-md-50">
                            <label for="catalogSelector" class="form-label me-3 m-0 text-nowrap fw-semibold text-muted">Seleccionar Catálogo:</label>
                            <select id="catalogSelector" class="form-select form-select-sm shadow-none border-primary">
                                <option value="">Cargando catálogos...</option>
                            </select>
                        </div>
                    </div>
                    
                    <div class="card-body p-4">
                        <div class="d-flex justify-content-end mb-3">
                            <button id="btnNewRecord" class="btn btn-primary btn-mobile-standard rounded-3 shadow-sm" style="display: none;" onclick="openModal('add')">
                                <i class="bi bi-plus-lg me-1"></i> Añadir Registro
                            </button>
                        </div>
                        
                        <div class="table-responsive" id="table-container">
                            <div class="text-center text-muted p-5">
                                <i class="bi bi-file-earmark-text fs-1 mb-2 d-block"></i>
                                Seleccione un catálogo para visualizar sus datos.
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div> <!-- End of Wrapper -->

<!-- Modal CRUD Dinamico -->
<div class="modal fade" id="crudModal" tabindex="-1" aria-hidden="true" data-bs-backdrop="static">
  <div class="modal-dialog modal-dialog-centered modal-lg">
    <div class="modal-content border-0 shadow-lg rounded-4">
      <div class="modal-header bg-light border-0 rounded-top-4">
        <h5 class="modal-title fw-bold" style="color: var(--md-blue-deep);" id="crudModalTitle"><i class="bi bi-pencil-square me-2 text-primary"></i> Registro</h5>
        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
      </div>
      <div class="modal-body p-4">
        <form id="crudForm">
            <div id="dynamic-form-fields" class="row"></div>
        </form>
      </div>
      <div class="modal-footer border-0 bg-light rounded-bottom-4">
        <button type="button" class="btn btn-secondary rounded-3" data-bs-dismiss="modal">Cancelar</button>
        <button type="button" class="btn btn-primary rounded-3 px-4 shadow-sm" onclick="saveRecord()">Guardar Cambios</button>
      </div>
    </div>
  </div>
</div>
HTML



my $cache_buster = time();
print <<"HTML";
    <script src="../js/gestion_catalogos.js?v=$cache_buster"></script>
    <script src="../js/session_watcher.js"></script>
</body>
</html>
HTML
