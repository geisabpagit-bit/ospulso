use FindBin;
use File::Spec;

# 1. Carga de Layouts con rutas absolutas
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_header.pl');
require File::Spec->catfile($FindBin::Bin, '..', 'utils', 'sub_footer.pl');

# --- FUNCIÓN CENTRAL: Renderiza el Error de Sesión ---
sub render_error_sesion {
    my (%args) = @_;

    # 1. Renderiza el encabezado para un invitado
    render_header(
        usuario          => 'Invitado',  
        titulo           => 'Error de Sesión',  
        ruta_logout      => '../index.html',  
        show_nav_content => 0, # No mostrar el navbar ni la búsqueda
        skip_header      => ($args{skip_header} // 0)

    );
    
    # 2. Imprime el contenido HTML de error
    print <<'HTML';
    <style>
        .error-card {
            background: white;
            border-radius: 2.5rem;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.1);
            padding: 4rem 2rem;
            text-align: center;
            max-width: 500px;
            width: 100%;
            border: 1px solid rgba(0,0,0,0.05);
        }
        .icon-shield {
            color: #ef4444;
            font-size: 4rem;
            margin-bottom: 2rem;
            display: inline-block;
            filter: drop-shadow(0 10px 15px rgba(239, 68, 68, 0.1));
        }
        .btn-medentia-login {
            background: #2563eb;
            color: white;
            border: none;
            padding: 0.8rem 2rem;
            border-radius: 1rem;
            font-weight: 700;
            transition: all 0.3s ease;
            text-decoration: none;
            display: inline-block;
            box-shadow: 0 4px 6px -1px rgba(37, 99, 235, 0.1);
        }
        .btn-medentia-login:hover {
            background: #1d4ed8;
            transform: translateY(-1px);
            box-shadow: 0 10px 15px -3px rgba(37, 99, 235, 0.2);
            color: white;
        }
    </style>
<div class="container d-flex justify-content-center align-items-center" style="min-height: 75vh;">
  <div class="error-card animate__animated animate__zoomIn">
    <div class="icon-shield">
        <i class="bi bi-shield-lock"></i>
    </div>
    <h3 class="fw-bold text-danger mb-3">Acceso Restringido - Sesi&oacute;n Expirada</h3>
    <p class="text-muted mb-4 fs-5 px-4">Tu sesi&oacute;n ha expirado o no se pudo cargar. Por favor, vuelve a iniciar sesi&oacute;n.</p>
    <div class="mt-2">
      <a href="../index.html" class="btn-medentia-login">
        <i class="bi bi-arrow-left me-2"></i>Volver al Login
      </a>
    </div>
  </div>
</div>
HTML
    
    # 3. Renderiza el pie de página
    render_footer();
}

1;
