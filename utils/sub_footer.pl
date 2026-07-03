#!/usr/bin/perl
use strict;
use warnings;
use utf8;

sub render_footer {
    my %args = @_;
    
    print <<'HTML';
    </main> <!-- Cerrar container principal -->
    
    <footer style="background: rgba(232, 243, 255, 0.96) !important; backdrop-filter: blur(15px) !important; -webkit-backdrop-filter: blur(15px) !important; color: var(--md-blue-deep) !important; padding: 3rem 0 !important; margin-top: auto; border-top: 1px solid rgba(10, 42, 102, 0.08) !important;">
        <div class="container-fluid px-5">
            <div class="row align-items-center g-4">
                <div class="col-lg-6">
                <img src="https://www.pdigitalesm.com/assets/logo-geisabpa.webp" alt="Logo GEISABPA" width="25" height="25">
                    <h5 class="plus-jakarta fw-bold mb-3" style="color: var(--md-blue-deep) !important;">GEISABPA <span style="font-weight:400; font-size:0.85rem; opacity:0.7">Plataformas Digitales de México</span></h5>
                    <div style="font-size: 0.9rem; opacity: 0.9;">
                        <p class="mb-1"><i class="bi bi-geo-alt-fill me-2" style="color: #00C4C4;"></i>Sierra Madre Oriental #163, La Pradera. CP 07500, CDMX</p>
                        <p class="mb-0"><i class="bi bi-telephone-fill me-2" style="color: #00C4C4;"></i>Tel: +52 56 4355 5072 | +52 55 7575 4269</p>
                    </div>
                </div>
                <div class="col-lg-6 text-lg-end">
                    <div class="d-flex flex-column align-items-lg-end">
                        <div class="d-flex gap-4 mb-3 justify-content-center justify-content-lg-end">
                            <a href="https://www.facebook.com/pdigitalesm/" target="_blank" style="color: var(--md-blue-deep); text-decoration: none; font-weight: 600;"><i class="bi bi-facebook me-2" style="color: #00C4C4;"></i>Facebook</a>
                            <a href="#" style="color: var(--md-blue-deep); text-decoration: none; opacity: 0.9;">Soporte</a>
                            <a href="#" style="color: var(--md-blue-deep); text-decoration: none; opacity: 0.9;">Privacidad</a>
                        </div>
                        <div style="font-size: 0.75rem; opacity: 0.7;">
                            &copy; 2026 Todos los derechos reservados. OSPulso.
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
