#!/usr/bin/perl
use cPanelUserConfig;
use strict;
use warnings;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use utf8;
use open qw(:std :utf8);
use FindBin;
use File::Spec;
use lib "$FindBin::Bin/..";
sub render_header; sub render_footer; sub render_bottom_nav;
require File::Spec->catfile($FindBin::Bin, '..', 'auth', 'check_session.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_bottom_nav.pl');

my $session_data = check_session();
my $q       = $session_data->{q};
my $session_ok = $session_data->{session_ok};
my $usuario = $session_data->{usuario};
my $role    = $session_data->{role};
my $id_emp  = $session_data->{id_empresa} || 0;

unless ($session_ok && ($role eq 'Administrador Organizacion' || $role eq 'Administrador Global')) {
    render_acceso_denegado(
        q => $q, usuario => ($usuario // 'Invitado'), role => ($role // 'Invitado'),
        mensaje => 'Esta sección es exclusiva para el Administrador de la Organización.',
        rol_requerido => 'Administrador Organización'
    );
    exit;
}

render_header(usuario => $usuario, titulo => "Catalogo de Servicios y Productos", ruta_logout => '../auth/cerrar_sesion.pl', role => $role, skip_header => 1);

print <<'HTML';
<div class="container-fluid px-3 py-3" id="appCatalogoOrg">

  <!-- Header de pagina -->
  <div class="d-flex justify-content-between align-items-center mb-4">
    <div>
      <h4 class="fw-bold m-0" style="font-family:'Plus Jakarta Sans',sans-serif; color:var(--md-blue-deep,#0A2A66);">
        <i class="bi bi-tags-fill me-2" style="color:#f59e0b;"></i>Catalogo de Servicios y Productos
      </h4>
      <small class="text-muted" id="labelOrgCatalogo">Cargando organizacion...</small>
    </div>
    <div class="d-flex gap-2 flex-wrap justify-content-end">
      <button class="btn btn-sm btn-outline-secondary rounded-pill px-3" onclick="importarCatalogoBase()">
        <i class="bi bi-cloud-download me-1"></i>Reimportar desde base
      </button>
    </div>
  </div>

  <!-- Tabs -->
  <ul class="nav nav-pills mb-4 gap-2" id="tabsCatalogo">
    <li class="nav-item">
      <button class="nav-link active fw-bold px-4 rounded-pill" id="tab-servicios" onclick="mostrarTab('servicios')">
        <i class="bi bi-clipboard2-pulse me-1"></i>Servicios
      </button>
    </li>
    <li class="nav-item">
      <button class="nav-link fw-bold px-4 rounded-pill" id="tab-productos" onclick="mostrarTab('productos')">
        <i class="bi bi-box-seam me-1"></i>Productos
      </button>
    </li>
  </ul>

  <!-- Panel Servicios -->
  <div id="panel-servicios">
    <div class="bento-card p-4 mb-3" style="border-radius:1.5rem;">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <h6 class="fw-bold m-0" style="color:var(--md-blue-deep,#0A2A66);">
          <i class="bi bi-clipboard2-pulse me-2" style="color:#f59e0b;"></i>Servicios de la Organizacion
        </h6>
        <button class="btn btn-sm fw-bold rounded-pill px-3" style="background:linear-gradient(135deg,#0A2A66,#124A9E);color:white;border:none;" onclick="abrirFormItem('servicio')">
          <i class="bi bi-plus-lg me-1"></i>Agregar Servicio
        </button>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle table-sm" id="tablaServicios">
          <thead style="background:var(--md-white-clinical,#F8FBFF);">
            <tr>
              <th class="small text-muted fw-bold text-uppercase" style="font-size:.7rem;">Nombre</th>
              <th class="small text-muted fw-bold text-uppercase text-end" style="font-size:.7rem;">Precio</th>
              <th class="small text-muted fw-bold text-uppercase" style="font-size:.7rem;">Descripcion</th>
              <th style="width:100px;"></th>
            </tr>
          </thead>
          <tbody id="tbodyServicios">
            <tr><td colspan="4" class="text-center text-muted py-4"><span class="spinner-border spinner-border-sm me-2"></span>Cargando...</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- Panel Productos -->
  <div id="panel-productos" class="d-none">
    <div class="bento-card p-4 mb-3" style="border-radius:1.5rem;">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <h6 class="fw-bold m-0" style="color:var(--md-blue-deep,#0A2A66);">
          <i class="bi bi-box-seam me-2" style="color:#f59e0b;"></i>Productos de la Organizacion
        </h6>
        <button class="btn btn-sm fw-bold rounded-pill px-3" style="background:linear-gradient(135deg,#0A2A66,#124A9E);color:white;border:none;" onclick="abrirFormItem('producto')">
          <i class="bi bi-plus-lg me-1"></i>Agregar Producto
        </button>
      </div>
      <div class="table-responsive">
        <table class="table table-hover align-middle table-sm" id="tablaProductos">
          <thead style="background:var(--md-white-clinical,#F8FBFF);">
            <tr>
              <th class="small text-muted fw-bold text-uppercase" style="font-size:.7rem;">Nombre</th>
              <th class="small text-muted fw-bold text-uppercase text-end" style="font-size:.7rem;">Precio</th>
              <th class="small text-muted fw-bold text-uppercase" style="font-size:.7rem;">Presentacion</th>
              <th class="small text-muted fw-bold text-uppercase text-end" style="font-size:.7rem;">Cant.</th>
              <th class="small text-muted fw-bold text-uppercase" style="font-size:.7rem;">Descripcion</th>
              <th style="width:100px;"></th>
            </tr>
          </thead>
          <tbody id="tbodyProductos">
            <tr><td colspan="6" class="text-center text-muted py-4"><span class="spinner-border spinner-border-sm me-2"></span>Cargando...</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>

</div>

<!-- Modal Form Item -->
<div class="modal fade" id="modalItemCatalogo" tabindex="-1">
  <div class="modal-dialog modal-dialog-centered">
    <div class="modal-content rounded-4 border-0 shadow-lg">
      <div class="modal-header border-0 px-4 pt-4" style="background:linear-gradient(135deg,#0A2A66,#f59e0b);">
        <h5 class="modal-title fw-bold text-white" id="modalItemTitle">Agregar Item</h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
      </div>
      <div class="modal-body p-4">
        <input type="hidden" id="itemEditId" value="">
        <input type="hidden" id="itemTipo" value="">
        <div class="mb-3">
          <label class="kpi-label">Nombre *</label>
          <input type="text" id="itemNombre" class="form-control mt-1 rounded-3" placeholder="Ej. Consulta General">
        </div>
        <div class="mb-3">
          <label class="kpi-label">Precio *</label>
          <div class="input-group mt-1">
            <span class="input-group-text fw-bold">$</span>
            <input type="number" id="itemPrecio" class="form-control rounded-end-3" placeholder="0.00" step="0.01" min="0">
          </div>
        </div>
        <div id="camposProducto" class="d-none">
          <div class="row g-2 mb-3">
            <div class="col-6">
              <label class="kpi-label">Cantidad</label>
              <input type="number" id="itemCantidad" class="form-control mt-1 rounded-3" placeholder="0" min="0">
            </div>
            <div class="col-6">
              <label class="kpi-label">Presentacion</label>
              <input type="text" id="itemPresentacion" class="form-control mt-1 rounded-3" placeholder="Ej. Caja 20 tab">
            </div>
          </div>
        </div>
        <div class="mb-3">
          <label class="kpi-label">Descripcion</label>
          <textarea id="itemDesc" class="form-control mt-1 rounded-3" rows="2" placeholder="Descripcion breve..."></textarea>
        </div>
      </div>
      <div class="modal-footer border-0 px-4 pb-4">
        <button type="button" class="btn btn-light rounded-pill px-4" data-bs-dismiss="modal">Cancelar</button>
        <button type="button" class="btn fw-bold rounded-pill px-4" id="btnGuardarItem"
          style="background:linear-gradient(135deg,#f59e0b,#d97706);color:white;border:none;"
          onclick="guardarItem()">
          <i class="bi bi-check-lg me-1"></i>Guardar
        </button>
      </div>
    </div>
  </div>
</div>

<script src="../js/catalogo_org_spa.js"></script>
HTML

render_bottom_nav('ajustes');
render_footer();
1;
