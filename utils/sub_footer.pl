#!/usr/bin/perl
use strict;
use warnings;
use utf8;

sub render_footer {
    my %args = @_;
    
    print <<'HTML';
    </main> <!-- Cerrar container principal -->
    
    <footer style="background: #0d1e3d; color: white; padding: 3rem 0; margin-top: auto; border-top: 1px solid rgba(255,255,255,0.1);">
        <div class="container-fluid px-5">
            <div class="row align-items-center g-4">
                <div class="col-lg-6">
                <img src="https://www.pdigitalesm.com/assets/logo-geisabpa.webp" alt="Logo GEISABPA" width="25" height="25">
                    <h5 class="plus-jakarta fw-bold text-white mb-3">GEISABPA <span style="font-weight:400; font-size:0.85rem; opacity:0.7">Plataformas Digitales de México</span></h5>
                    <div style="font-size: 0.9rem; opacity: 0.8;">
                        <p class="mb-1"><i class="bi bi-geo-alt-fill me-2"></i>Sierra Madre Oriental #163, La Pradera. CP 07500, CDMX</p>
                        <p class="mb-0"><i class="bi bi-telephone-fill me-2"></i>Tel: +52 56 4355 5072 | +52 55 7575 4269</p>
                    </div>
                </div>
                <div class="col-lg-6 text-lg-end">
                    <div class="d-flex flex-column align-items-lg-end">
                        <div class="d-flex gap-4 mb-3 justify-content-center justify-content-lg-end">
                            <a href="https://www.facebook.com/pdigitalesm/" target="_blank" style="color:white; text-decoration:none; font-weight:600;"><i class="bi bi-facebook me-2"></i>Facebook</a>
                            <a href="#" style="color:white; text-decoration:none; opacity:0.8;">Soporte</a>
                            <a href="#" style="color:white; text-decoration:none; opacity:0.8;">Privacidad</a>
                        </div>
                        <div style="font-size: 0.75rem; opacity: 0.5;">
                            &copy; 2026 Todos los derechos reservados. Software Dental Mexicano.
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
</body>
</html>
HTML
}
1;
