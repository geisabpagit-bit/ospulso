// js/visor_medico_spa.js

// Controlador SPA para SDM Viewer Pro



const VisorApp = {

    id_paciente: null,

    estudios: [],

    element: null,

    imageWrapper: null,

    currentFile: null,

    

    id_paciente: null,

    estudios: [],

    element: null,

    currentFile: null,

    currentImageIndex: 1,

    currentSerieLength: 1,

    currentSerieDesc: '',

    

    // UI State

    currentTool: 'pan',



    init: function() {

        console.log("Inicializando SDM Viewer Pro con Cornerstone.js...");

        this.id_paciente = window.ID_PACIENTE || null;

        this.element = document.getElementById('dicomImage');

        

        if (!this.id_paciente) {

            Swal.fire('Error', 'No se ha definido un ID de paciente.', 'error');

            return;

        }



        // Configurar Cornerstone

        cornerstoneWADOImageLoader.external.cornerstone = cornerstone;

        cornerstoneWADOImageLoader.external.dicomParser = dicomParser;

        cornerstoneWebImageLoader.external.cornerstone = cornerstone;



        // Registrar esquemas para soporte de Canvas local (Drag & Drop)

        cornerstone.registerImageLoader('blob', cornerstoneWebImageLoader.loadImage);

        cornerstone.registerImageLoader('data', cornerstoneWebImageLoader.loadImage);



        // Configurar Web Workers para WADO

        cornerstoneWADOImageLoader.webWorkerManager.initialize({

            maxWebWorkers: navigator.hardwareConcurrency || 1,

            startWebWorkersOnDemand: true,

            taskConfiguration: {

                decodeTask: { initializeCodecsOnStartup: false }

            }

        });



        // Inicializar CornerstoneTools

        cornerstoneTools.external.cornerstone = cornerstone;

        cornerstoneTools.external.cornerstoneMath = cornerstoneMath;

        cornerstoneTools.external.Hammer = window.Hammer || undefined;

        cornerstoneTools.init({ showSVGCursors: true });



        // Inicializar Elemento Cornerstone

        cornerstone.enable(this.element);



        // Agregar herramientas al elemento

        cornerstoneTools.addTool(cornerstoneTools.PanTool);

        cornerstoneTools.addTool(cornerstoneTools.ZoomTool);

        cornerstoneTools.addTool(cornerstoneTools.WwwcTool);

        cornerstoneTools.addTool(cornerstoneTools.LengthTool);

        cornerstoneTools.addTool(cornerstoneTools.AngleTool);

        cornerstoneTools.addTool(cornerstoneTools.ArrowAnnotateTool);

        cornerstoneTools.addTool(cornerstoneTools.ProbeTool);

        cornerstoneTools.addTool(cornerstoneTools.FreehandRoiTool);

        cornerstoneTools.addTool(cornerstoneTools.ZoomMouseWheelTool);



        // Activar PanTool por defecto (Boton izquierdo)

        // Y Zoom (Click derecho)

        cornerstoneTools.setToolActive('Pan', { mouseButtonMask: 1 });

        cornerstoneTools.setToolActive('Zoom', { mouseButtonMask: 2 });

        cornerstoneTools.setToolActive('Wwwc', { mouseButtonMask: 4 }); // Rueda (click)

        cornerstoneTools.setToolActive('ZoomMouseWheel', { }); // Rueda (scroll)



        this.bindEvents();

        this.loadEstudios();

    },



    bindEvents: function() {

        this.element.addEventListener('cornerstonetoolsmeasurementadded', () => this.renderCapas());

        this.element.addEventListener('cornerstonetoolsmeasurementmodified', () => this.renderCapas());

        this.element.addEventListener('cornerstonetoolsmeasurementremoved', () => this.renderCapas());

        this.element.addEventListener('cornerstoneimagerendered', (e) => this.updateOverlays(e));



        // --- 1. TOOLBAR ACTIONS ---

        const toolBtns = document.querySelectorAll('.tool-btn[data-action]');

        toolBtns.forEach(btn => {

            btn.addEventListener('click', (e) => {

                const action = btn.getAttribute('data-action');

                

                // Toggle active state for select/pan

                if (action === 'select' || action === 'pan') {

                    document.querySelectorAll('.tool-btn[data-action="select"], .tool-btn[data-action="pan"], .tool-btn[data-tool]').forEach(b => b.classList.remove('active'));

                    btn.classList.add('active');

                    this.currentTool = action;

                    this.element.style.cursor = action === 'pan' ? 'grab' : 'crosshair';

                }

                

                this.handleToolbarAction(action);

            });

        });



        // --- 2. CANVAS MOUSE EVENTS ---

        // Cornerstone maneja internamente los eventos del mouse.

        // Solo necesitamos reaccionar al redimensionamiento de ventana.

        window.addEventListener('resize', () => {

            cornerstone.resize(this.element, true);

        });



        // --- 3. SLIDERS (ZOOM / BRIGHTNESS / CONTRAST) ---

        const sliderZoom = document.getElementById('slider-zoom');

        const labelZoom = document.getElementById('label-zoom');

        const sliderWW = document.getElementById('slider-ww'); // Contraste

        const labelWW = document.getElementById('label-ww');

        const sliderWL = document.getElementById('slider-wl'); // Brillo
        const labelWL = document.getElementById('label-wl');
        const btnResetSliders = document.getElementById('btn-reset-sliders');
        
        // Carousel scroll buttons
        const btnScrollLeft = document.getElementById('btn-scroll-left');
        const btnScrollRight = document.getElementById('btn-scroll-right');
        const carouselContainer = document.getElementById('series-thumbnails-container');

        if (btnScrollLeft && carouselContainer) {
            btnScrollLeft.addEventListener('click', () => {
                carouselContainer.scrollBy({ left: -200, behavior: 'smooth' });
            });
        }
        if (btnScrollRight && carouselContainer) {
            btnScrollRight.addEventListener('click', () => {
                carouselContainer.scrollBy({ left: 200, behavior: 'smooth' });
            });
        }



        if (sliderZoom) {

            sliderZoom.addEventListener('input', (e) => {

                const z = parseInt(e.target.value) / 100;

                if (this.element) {

                    const viewport = cornerstone.getViewport(this.element);

                    if (viewport) {

                        viewport.scale = z;

                        cornerstone.setViewport(this.element, viewport);

                    }

                }

                labelZoom.textContent = e.target.value + '%';

            });

        }

        if (sliderWW) {

            sliderWW.addEventListener('input', (e) => {

                const percentage = parseInt(e.target.value) / 100;

                if (this.element) {

                    const viewport = cornerstone.getViewport(this.element);

                    const image = cornerstone.getImage(this.element);

                    if (viewport && image && image.windowWidth !== undefined) {

                        viewport.voi.windowWidth = image.windowWidth * percentage;

                        cornerstone.setViewport(this.element, viewport);

                    }

                }

                labelWW.textContent = e.target.value + '%';

            });

        }

        if (sliderWL) {

            sliderWL.addEventListener('input', (e) => {

                const percentage = parseInt(e.target.value) / 100;

                if (this.element) {

                    const viewport = cornerstone.getViewport(this.element);

                    const image = cornerstone.getImage(this.element);

                    if (viewport && image && image.windowCenter !== undefined) {

                        viewport.voi.windowCenter = image.windowCenter * percentage;

                        cornerstone.setViewport(this.element, viewport);

                    }

                }

                labelWL.textContent = e.target.value + '%';

            });

        }

        if (btnResetSliders) {

            btnResetSliders.addEventListener('click', () => {

                if (sliderZoom) { sliderZoom.value = 100; labelZoom.textContent = '100%'; }

                if (sliderWW) { sliderWW.value = 100; labelWW.textContent = '100%'; }

                if (sliderWL) { sliderWL.value = 100; labelWL.textContent = '100%'; }

                this.applyPreset('normal');

            });

        }



        // --- 4. RIGHT SIDEBAR TOOLS (ANNOTATIONS) ---

        const gridItems = document.querySelectorAll('.tool-btn[data-tool]');
        const allToolBtns = document.querySelectorAll('.tool-btn[data-action="select"], .tool-btn[data-action="pan"], .tool-btn[data-tool]');

        gridItems.forEach(item => {

            item.addEventListener('click', () => {

                const tool = item.getAttribute('data-tool');

                if (tool === 'borrar') {

                    Swal.fire({

                        title: 'Eliminar anotaciones?',

                        text: "Se borrarn todas las mediciones y figuras del lienzo actual.",

                        icon: 'warning',

                        showCancelButton: true,

                        confirmButtonColor: '#d33',

                        cancelButtonColor: '#3085d6',

                        confirmButtonText: 'Si, borrar todo',

                        cancelButtonText: 'Cancelar'

                    }).then((result) => {

                        if (result.isConfirmed) {

                            cornerstoneTools.clearToolState(this.element, 'Length');

                            cornerstoneTools.clearToolState(this.element, 'Angle');

                            cornerstoneTools.clearToolState(this.element, 'ArrowAnnotate');

                            cornerstoneTools.clearToolState(this.element, 'Probe');

                            cornerstoneTools.clearToolState(this.element, 'FreehandRoi');

                            cornerstone.updateImage(this.element);

                            this.renderCapas();

                            Swal.fire('Borrado', 'Las anotaciones han sido eliminadas.', 'success');

                        }

                    });

                    return;

                }

                

                allToolBtns.forEach(i => i.classList.remove('active', 'shadow-sm'));

                item.classList.add('active', 'shadow-sm');

                this.currentTool = tool;

                

                // Mapear el string al Tool Name de Cornerstone

                let csTool = 'Pan';

                if (tool === 'medir') csTool = 'Length';

                else if (tool === 'angulo') csTool = 'Angle';

                else if (tool === 'texto') csTool = 'ArrowAnnotate';

                else if (tool === 'roi') csTool = 'Probe'; // Probe is closest to ROI point density for now

                else if (tool === 'poligono') csTool = 'FreehandRoi';

                

                cornerstoneTools.setToolActive(csTool, { mouseButtonMask: 1 });

                

                // Desactivar botones de la barra izquierda

                document.querySelectorAll('.tool-btn[data-action="pan"], .tool-btn[data-action="select"]').forEach(b => b.classList.remove('active'));

            });

        });



        const btnNewCapa = document.getElementById('btn-new-capa');

        if (btnNewCapa) {

            btnNewCapa.addEventListener('click', () => {

                Swal.fire('Informacion', 'Selecciona una herramienta (Medir, Texto, ROI) y haz clic en la imagen para crear una anotacion dinamicamente.', 'info');

            });

        }



        // --- 5. SEARCH ESTUDIOS ---

        const searchInput = document.getElementById('search-estudios');

        if (searchInput) {

            searchInput.addEventListener('input', (e) => {

                const term = e.target.value.toLowerCase();

                this.aplicarFiltrosDirecto(term);

            });

        }



        const btnAplicarFiltros = document.getElementById('btn-aplicar-filtros');

        const btnResetFiltros = document.getElementById('btn-reset-filtros');

        if (btnAplicarFiltros) {

            btnAplicarFiltros.addEventListener('click', () => {

                this.aplicarFiltrosDirecto(searchInput ? searchInput.value.toLowerCase() : '');

            });

        }

        if (btnResetFiltros) {

            btnResetFiltros.addEventListener('click', () => {

                const fN = document.getElementById('filter-nombre');

                const fM = document.getElementById('filter-modalidad');

                const fF = document.getElementById('filter-fecha');

                if(fN) fN.value = '';

                if(fM) fM.value = '';

                if(fF) fF.value = '';

                if(searchInput) searchInput.value = '';

                this.aplicarFiltrosDirecto('');

            });

        }



        // --- 6. HEADER BUTTONS (FILE, EXPORT, PRINT) ---

        const btnOpen = document.getElementById('btn-open-file');

        const fileInput = document.getElementById('file-input');



        if (btnOpen && fileInput) {

            btnOpen.addEventListener('click', () => {

                const activeContainer = document.querySelector('.study-item.active');

                if (!activeContainer) {

                    Swal.fire('Atencion', 'Seleccione un estudio de la lista izquierda para abrir/adjuntar una imagen.', 'warning');

                    return;

                }

                fileInput.click();

            });

            fileInput.addEventListener('change', (e) => {

                const file = e.target.files[0];

                if (file) {

                    const activeContainer = document.querySelector('.study-item.active');

                    if (!activeContainer) return;

                    const estudioId = activeContainer.getAttribute('data-id-estudio');

                    

                    const formData = new FormData();

                    formData.append('id_paciente', window.ID_PACIENTE);

                    formData.append('id_estudio', estudioId);

                    formData.append('archivo_estudio', file);



                    Swal.fire({

                        title: 'Subiendo...',

                        text: 'Adjuntando imagen al estudio actual',

                        allowOutsideClick: false,

                        didOpen: () => Swal.showLoading()

                    });



                    axios.post('../api/guardar_estudio_api.pl', formData, {

                        headers: { 'Content-Type': 'multipart/form-data' }

                    })

                    .then(response => {

                        if (response.data && response.data.ok) {

                            Swal.fire('Guardado', 'La imagen se adjunto correctamente.', 'success');

                            this.loadEstudios();

                        } else {

                            Swal.fire('Error', response.data.msg || 'Error al guardar.', 'error');

                        }

                    })

                    .catch(err => {

                        console.error("Error al subir archivo:", err);

                        Swal.fire('Error', 'Error de comunicacion con el servidor.', 'error');

                    })

                    .finally(() => {

                        fileInput.value = '';

                    });

                }

            });

        }



        const formNuevo = document.getElementById('form-nuevo-estudio');

        if (formNuevo) {

            formNuevo.addEventListener('submit', (e) => this.crearEstudio(e));

        }



        const btnExport = document.getElementById('btn-export');

        if (btnExport) {

            btnExport.addEventListener('click', () => {

                Swal.fire({

                    title: 'Generando Imagen',

                    text: 'Capturando lienzo y anotaciones...',

                    allowOutsideClick: false,

                    didOpen: () => Swal.showLoading()

                });

                

                setTimeout(() => {

                    const dicomContainer = document.getElementById('dicomImage');

                    if (window.html2canvas && dicomContainer) {

                        html2canvas(dicomContainer, { backgroundColor: '#000' }).then(canvas => {

                            const link = document.createElement('a');

                            link.download = 'estudio_exportado.jpg';

                            link.href = canvas.toDataURL('image/jpeg', 0.9);

                            link.click();

                            Swal.close();

                        }).catch(err => {

                            console.error(err);

                            Swal.fire('Error', 'No se pudo generar la imagen.', 'error');

                        });

                    } else {

                        // Fallback

                        cornerstoneTools.SaveAs(this.element, "estudio_exportado.jpg", "image/jpeg");

                        Swal.close();

                    }

                }, 500);

            });

        }



        const btnPrint = document.getElementById('btn-print');

        if (btnPrint) {

            btnPrint.addEventListener('click', () => {

                Swal.fire({

                    title: 'Preparando Impresi\u00f3n',

                    text: 'Generando documento cl\u00ednico...',

                    allowOutsideClick: false,

                    didOpen: () => Swal.showLoading()

                });

                

                setTimeout(() => {

                    const dicomContainer = document.getElementById('dicomImage');

                    if (window.html2canvas && dicomContainer) {

                        html2canvas(dicomContainer, { backgroundColor: '#000' }).then(canvas => {

                            const printImg = document.getElementById('print-image-container');

                            const printDate = document.getElementById('print-date');

                            if (printImg) printImg.src = canvas.toDataURL('image/jpeg', 0.9);

                            if (printDate) {

                                const d = new Date();

                                printDate.textContent = `${d.getDate().toString().padStart(2,'0')}/${(d.getMonth()+1).toString().padStart(2,'0')}/${d.getFullYear()} ${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}`;

                            }

                            

                            // Extraer anotaciones

                            const annotationsDiv = document.getElementById('print-annotations');

                            if (annotationsDiv) {

                                let html = '<table class="table table-sm table-bordered mt-3 text-start" style="font-size: 0.85rem;">';

                                html += '<thead class="table-light"><tr><th class="w-25">Tipo de Anotaci&oacute;n</th><th>Valor / Detalle</th></tr></thead><tbody>';

                                let hasAnnotations = false;

                                

                                const element = document.getElementById('dicomImage');

                                const toolsToCheck = ['Length', 'Angle', 'ArrowAnnotate'];

                                toolsToCheck.forEach(tool => {

                                    const toolState = cornerstoneTools.getToolState(element, tool);

                                    if (toolState && toolState.data && toolState.data.length > 0) {

                                        toolState.data.forEach((data, index) => {

                                            hasAnnotations = true;

                                            let tipo = tool === 'Length' ? 'Medici&oacute;n' : (tool === 'Angle' ? '&Aacute;ngulo' : 'Texto');

                                            let detalle = '';

                                            if (tool === 'Length' && data.length) detalle = data.length.toFixed(2) + ' mm';

                                            else if (tool === 'Angle' && data.text) detalle = data.text;

                                            else if (tool === 'ArrowAnnotate' && data.text) detalle = data.text;

                                            else detalle = 'Registrada en imagen';

                                            html += `<tr><td class="fw-bold">${tipo} ${index + 1}</td><td>${detalle}</td></tr>`;

                                        });

                                    }

                                });

                                

                                html += '</tbody></table>';

                                annotationsDiv.innerHTML = hasAnnotations ? html : '<p class="text-muted small">No hay anotaciones textuales o num&eacute;ricas vinculadas a esta imagen.</p>';

                            }



                            Swal.close();

                            // Pequeo timeout para que el DOM se actualice antes de abrir el dilogo de impresin

                            setTimeout(() => {

                                window.print();

                            }, 300);

                        }).catch(err => {

                            console.error(err);

                            Swal.fire('Error', 'No se pudo generar el documento.', 'error');

                        });

                    } else {

                        Swal.close();

                        window.print();

                    }

                }, 500);

            });

        }



        // --- 7. PRESETS / FILTROS ---

        const presetBtns = document.querySelectorAll('.preset-btn[data-preset]');

        presetBtns.forEach(btn => {

            btn.addEventListener('click', () => {

                const preset = btn.getAttribute('data-preset');

                this.applyPreset(preset);

            });

        });



        // --- 8. MOBILE NAVIGATION ---

        const mobileBtns = document.querySelectorAll('.mobile-nav-btn');

        const sideLeft = document.querySelector('.visor-sidebar-left');

        const sideRight = document.querySelector('.visor-sidebar-right');

        

        mobileBtns.forEach((btn, index) => {

            btn.addEventListener('click', () => {

                mobileBtns.forEach(b => b.classList.remove('active'));

                btn.classList.add('active');

                

                if (window.innerWidth <= 768) {

                    if (index === 0) { // Imgenes

                        sideLeft.style.display = 'none';

                        sideRight.style.display = 'none';

                    } else if (index === 1) { // Estudios

                        sideLeft.style.display = 'flex';

                        sideRight.style.display = 'none';

                    } else if (index === 2 || index === 3) { // Capas / Herram

                        sideLeft.style.display = 'none';

                        sideRight.style.display = 'flex';

                    }

                }

            });

        });

    },



    handleToolbarAction: function(action) {

        if (!this.element) return;

        

        const viewport = cornerstone.getViewport(this.element);

        if (!viewport) return;

        

        switch(action) {

            case 'zoom-in':

                viewport.scale += 0.2;

                cornerstone.setViewport(this.element, viewport);

                break;

            case 'zoom-out':

                viewport.scale -= 0.2;

                cornerstone.setViewport(this.element, viewport);

                break;

            case 'rotate-left':

                viewport.rotation -= 90;

                cornerstone.setViewport(this.element, viewport);

                break;

            case 'rotate-right':

                viewport.rotation += 90;

                cornerstone.setViewport(this.element, viewport);

                break;

            case 'flip-v':

                viewport.vflip = !viewport.vflip;

                cornerstone.setViewport(this.element, viewport);

                break;

            case 'flip-h':

                viewport.hflip = !viewport.hflip;

                cornerstone.setViewport(this.element, viewport);

                break;

            case 'reset':

                cornerstone.reset(this.element);

                break;

            case 'pan':

                cornerstoneTools.setToolActive('Pan', { mouseButtonMask: 1 });

                break;

            case 'select':

                // Reset to default pan or window/level depending on preference

                cornerstoneTools.setToolActive('Wwwc', { mouseButtonMask: 1 });

                break;

        }

    },



    applyPreset: function(preset) {

        if (!this.element) return;

        const viewport = cornerstone.getViewport(this.element);

        const image = cornerstone.getImage(this.element);

        if (!viewport || !image) return;

        

        switch(preset) {

            case 'normal':

                viewport.invert = false;

                if (image.windowWidth !== undefined && image.windowCenter !== undefined) {

                    viewport.voi.windowWidth = image.windowWidth;

                    viewport.voi.windowCenter = image.windowCenter;

                }

                break;

            case 'invert':

                viewport.invert = !viewport.invert;

                break;

            case 'bone':

                if (image.windowWidth !== undefined && image.windowCenter !== undefined) {

                    viewport.voi.windowWidth = image.windowWidth * 1.6;

                    viewport.voi.windowCenter = image.windowCenter * 1.6;

                }

                break;

            case 'bw':

                viewport.voi.windowWidth = 400;

                viewport.voi.windowCenter = 40;

                break;

            case 'reset':

                cornerstone.reset(this.element);

                return;

        }

        cornerstone.setViewport(this.element, viewport);

    },



    updateOverlays: function(e) {

        if (!e.detail) return;

        const viewport = e.detail.viewport;

        const image = e.detail.image;

        if (!viewport || !image) return;



        // Bottom-Left (Windowing & Thickness)

        const overlayBlWlww = document.getElementById('overlay-bl-wlww');

        if (overlayBlWlww && viewport.voi) {

            overlayBlWlww.textContent = `WL: ${Math.round(viewport.voi.windowCenter)} WW: ${Math.round(viewport.voi.windowWidth)}`;

        }

        

        // Bottom-Right (Zoom & Dimensiones)

        const overlayBrZoom = document.getElementById('overlay-br-zoom');

        if (overlayBrZoom) {

            overlayBrZoom.textContent = `Zoom: ${Math.round(viewport.scale * 100)}%`;

        }

        const overlayBrRes = document.getElementById('overlay-br-res');

        if (overlayBrRes) {

            overlayBrRes.textContent = `${image.columns} x ${image.rows}`;

        }



        // --- Sincronizacin de Calibradores (UI) ---

        // Esto permite que si el usuario aplica un preset (como hueso) o usa el mouse,

        // los sliders reflejen el porcentaje actual relativo a los valores originales.

        const sliderWW = document.getElementById('slider-ww');

        const sliderWL = document.getElementById('slider-wl');

        const labelWW = document.getElementById('label-ww');

        const labelWL = document.getElementById('label-wl');



        if (sliderWW && labelWW && image.windowWidth !== undefined && image.windowWidth !== 0) {

            const percWW = Math.round((viewport.voi.windowWidth / image.windowWidth) * 100);

            // Cap to slider max to prevent breaking the UI logic visually, but update the text correctly

            sliderWW.value = Math.min(Math.max(percWW, 0), 500); 

            labelWW.textContent = percWW + '%';

        }

        if (sliderWL && labelWL && image.windowCenter !== undefined && image.windowCenter !== 0) {

            const percWL = Math.round((viewport.voi.windowCenter / image.windowCenter) * 100);

            sliderWL.value = Math.min(Math.max(percWL, 0), 500);

            labelWL.textContent = percWL + '%';

        }

        

        // Top-Right (Serie e Imagen)

        const overlayTrDesc = document.getElementById('overlay-tr-desc');

        if (overlayTrDesc) overlayTrDesc.textContent = this.currentSerieDesc || 'Sin descripcin';

        

        const overlayTrImage = document.getElementById('overlay-tr-image');

        if (overlayTrImage) overlayTrImage.textContent = `Imagen: ${this.currentImageIndex}/${this.currentSerieLength}`;



        // Top-Left & DICOM specific metadata 

        // Fallbacks para JPG o cuando no hay metadata DICOM

        const overlayBlThickness = document.getElementById('overlay-bl-thickness');

        if (overlayBlThickness) overlayBlThickness.textContent = '';

        

        try {

            // Intenta extraer metadata nativa (Solo WADO / DICOM)

            const isDicom = image.imageId && image.imageId.includes('wadouri:');

            

            if (isDicom && cornerstone.metaData) {

                // Slice Thickness (0018, 0050) y Spacing

                const imagePlane = cornerstone.metaData.get('imagePlaneModule', image.imageId);

                if (imagePlane) {

                    let textT = '';

                    if (imagePlane.sliceThickness) textT += `T: ${imagePlane.sliceThickness.toFixed(2)}mm `;

                    if (imagePlane.sliceLocation) textT += `L: ${imagePlane.sliceLocation.toFixed(2)}mm`;

                    if (overlayBlThickness) overlayBlThickness.textContent = textT;

                }

                

                // Tiempo del Estudio (0008, 0030) u Hora

                const generalStudy = cornerstone.metaData.get('generalStudyModule', image.imageId);

                const overlayTlTime = document.getElementById('overlay-tl-time');

                if (generalStudy && generalStudy.studyTime && overlayTlTime) {

                    const st = generalStudy.studyTime; // usually HHMMSS.ffffff

                    if (st.length >= 6) {

                        overlayTlTime.textContent = `${st.substring(0,2)}:${st.substring(2,4)}:${st.substring(4,6)}`;

                    }

                }

            }

        } catch (err) {

            // Ignore if metadata parsing fails

        }

    },



    // --- Cornerstone handles transformations and mouse events natively ---

    // (Funciones antiguas de transformaciones manuales eliminadas)



    renderDicomThumbnail: function(imgElement, ruta) {

        if (imgElement.dataset.rendered === "true") return;

        imgElement.dataset.rendered = "true";

        

        let url = ruta;

        if (ruta.startsWith('dat/')) {

            url = `../api/read_estudio_api.pl?ruta=${encodeURIComponent(ruta)}`;

        }

        url = window.location.origin + window.location.pathname.replace('render_visor_medico.pl', '') + url;

        let imageId = "wadouri:" + url;



        cornerstone.loadImage(imageId).then(image => {

            const canvas = document.createElement('canvas');

            canvas.width = 120;

            canvas.height = 120;

            cornerstone.renderToCanvas(canvas, image);

            imgElement.src = canvas.toDataURL('image/jpeg', 0.8);

        }).catch(err => {

            console.error("No se pudo generar miniatura DICOM:", err);

            imgElement.src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20width%3D%2260%22%20height%3D%2260%22%20viewBox%3D%220%200%2060%2060%22%3E%3Crect%20width%3D%2260%22%20height%3D%2260%22%20fill%3D%22%23cccccc%22%2F%3E%3Ctext%20x%3D%2250%25%22%20y%3D%2250%25%22%20dominant-baseline%3D%22middle%22%20text-anchor%3D%22middle%22%20fill%3D%22%23333333%22%20font-family%3D%22sans-serif%22%20font-size%3D%2212%22%3EDICOM%3C%2Ftext%3E%3C%2Fsvg%3E';

        });

    },



    renderCapas: function() {

        const list = document.getElementById('capas-list');

        if (!list) return;

        

        const toolsToCheck = ['Length', 'Angle', 'ArrowAnnotate', 'Probe', 'FreehandRoi'];

        let html = '';

        

        toolsToCheck.forEach(toolName => {

            const toolState = cornerstoneTools.getToolState(this.element, toolName);

            if (toolState && toolState.data) {

                toolState.data.forEach((data, index) => {

                    let text = toolName;

                    if (toolName === 'Length' && data.length) text = 'Medici&oacute;n ' + data.length.toFixed(1) + ' mm';

                    else if (toolName === 'Angle') text = '&Aacute;ngulo';

                    else if (toolName === 'ArrowAnnotate' && data.text) text = 'Texto: ' + data.text;

                    else if (toolName === 'FreehandRoi') text = 'Pol&iacute;gono';

                    else if (toolName === 'Probe') text = 'ROI (Punto)';



                    html += `

                        <div class="list-group-item d-flex justify-content-between align-items-center px-2 py-1 border-0 border-bottom bg-transparent" style="font-size: 0.8rem;">

                            <span class="text-truncate text-secondary fw-semibold" style="max-width: 150px;"><i class="bi bi-layers text-primary me-2"></i> ${text}</span>

                            <button class="btn btn-link text-danger p-0 m-0" onclick="VisorApp.removeAnnotation('${toolName}', ${index})" title="Eliminar"><i class="bi bi-trash"></i></button>

                        </div>

                    `;

                });

            }

        });

        

        if (html === '') {

            html = '<div class="text-muted text-center py-2" style="font-size: 0.8rem;"><i class="bi bi-info-circle d-block mb-1"></i>No hay anotaciones activas</div>';

        }

        

        list.innerHTML = html;

    },



    removeAnnotation: function(toolName, index) {

        const toolState = cornerstoneTools.getToolState(this.element, toolName);

        if (toolState && toolState.data && toolState.data[index]) {

            toolState.data.splice(index, 1);

            cornerstone.updateImage(this.element);

            this.renderCapas();

        }

    },



    aplicarFiltrosDirecto: function(globalTerm) {

        const fN = document.getElementById('filter-nombre');

        const filterNombre = fN ? fN.value.toLowerCase() : '';

        const fM = document.getElementById('filter-modalidad');

        const filterModalidad = fM ? fM.value : '';

        const fF = document.getElementById('filter-fecha');

        const filterFecha = fF ? fF.value : '';

        

        document.querySelectorAll('.study-item').forEach(item => {

            const text = item.innerText.toLowerCase();

            const rawDate = item.getAttribute('data-fecha') || '';

            const rawMod = item.getAttribute('data-modalidad') || '';

            

            let show = true;

            if (globalTerm && !text.includes(globalTerm)) show = false;

            if (filterNombre && !text.includes(filterNombre)) show = false;

            if (filterModalidad && rawMod !== filterModalidad) show = false;

            if (filterFecha && !rawDate.startsWith(filterFecha)) show = false;

            

            item.style.display = show ? 'block' : 'none';

        });

    },



    crearEstudio: function(e) {

        e.preventDefault();

        const btnSubmit = document.getElementById('btn-submit-nuevo');

        if(!btnSubmit) return;

        

        const modalidad = document.getElementById('nuevoModalidad').value;

        const desc = document.getElementById('nuevoDesc').value;

        

        if (!desc.trim()) {

            Swal.fire('Atencion', 'El nombre de estudio es obligatorio.', 'warning');

            return;

        }



        btnSubmit.disabled = true;

        btnSubmit.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span> Creando...';



        const formData = new FormData();

        formData.append('id_paciente', window.ID_PACIENTE);

        formData.append('nombre_estudio', desc);

        formData.append('modalidad', modalidad);



        axios.post('../api/crear_estudio_api.pl', formData)

        .then(response => {

            if (response.data.ok) {

                bootstrap.Modal.getInstance(document.getElementById('modalNuevoEstudio')).hide();

                Swal.fire('Creado', response.data.msg || 'El estudio se creo exitosamente.', 'success');

                document.getElementById('nuevoDesc').value = '';

                this.loadEstudios();

            } else {

                Swal.fire('Error', response.data.msg || 'Ocurrio un error al crear.', 'error');

            }

        })

        .catch(err => {

            console.error(err);

            Swal.fire('Error', 'Fallo en el servidor o timeout.', 'error');

        })

        .finally(() => {

            btnSubmit.disabled = false;

            btnSubmit.innerHTML = 'Crear Estudio <i class="bi bi-plus-circle ms-1"></i>';

        });

    },



    loadEstudios: function() {
        console.log("Consultando estudios para el paciente:", this.id_paciente);
        return axios.get(`../api/get_estudios_api.pl?id_paciente=${this.id_paciente}`)

            .then(response => {

                if (response.data && response.data.ok) {

                    this.estudios = response.data.data || [];

                    this.renderEstudiosSidebar();

                } else {

                    console.warn("No se pudieron cargoo los estudios.");

                }

            })

            .catch(err => console.error("Error consultando API de estudios:", err));

    },



    renderEstudiosSidebar: function() {

        const seriesContainerDynamic = document.getElementById('series-container-dynamic');

        const uploadDestino = document.getElementById('uploadDestino');

        

        let htmlEstudios = '';

        let optionsDestino = '<option value="nuevo">-- Crear Nuevo Estudio --</option>';



        if (this.estudios.length === 0) {

            htmlEstudios = `

                <div class="p-4 text-center text-muted small bg-light rounded">

                    <i class="bi bi-info-circle fs-3 d-block mb-2"></i>

                    No hay estudios PACS disponibles para este paciente.

                </div>

            `;

        } else {

            const urlParams = new URLSearchParams(window.location.search);

            const targetId = urlParams.get('estudio_id');

            let targetIndex = 0;

            

            if (targetId) {

                const foundIndex = this.estudios.findIndex(e => e.id_estudio == targetId);

                if (foundIndex !== -1) targetIndex = foundIndex;

            }



            let dataListOptions = '';

            this.estudios.forEach((est, index) => {

                const isActive = index === targetIndex ? 'active border-primary border-2 bg-primary-subtle' : 'border bg-white shadow-sm';

                dataListOptions += `<option value="${est.descripcion}">`;

                

                let thumbsHtml = '';

                if (est.imagenes && est.imagenes.length > 0) {

                    est.imagenes.forEach((img, i) => {

                        const safeRuta = img.ruta.replace(/\\/g, '/');

                        thumbsHtml += `

                            <div class="position-relative me-2 mb-2 d-inline-block" style="width: 60px; height: 60px; cursor: pointer;" onclick="VisorApp.loadSerie('${safeRuta}', this.parentElement.parentElement)">

                                <img src="../api/read_estudio_api.pl?ruta=${encodeURIComponent(safeRuta)}" class="w-100 h-100 object-fit-cover rounded border" onerror="this.onerror=null; VisorApp.renderDicomThumbnail(this, '${safeRuta}');">

                                <span class="position-absolute bottom-0 end-0 bg-dark text-white rounded-start px-1" style="font-size:0.65rem;">${i+1}</span>

                            </div>

                        `;

                    });

                } else {

                    thumbsHtml = `<div class="text-muted small fst-italic text-center my-2 p-2 bg-light rounded w-100">Estudio sin im&aacute;genes a&uacute;n</div>`;

                }



                htmlEstudios += `
                <div class="col-12">
                    <div class="card h-100 border-2 card-estudio p-2 study-item ${isActive}" data-id-estudio="${est.id_estudio}" data-fecha="${est.fecha}" data-modalidad="${est.modalidad}" style="transition: 0.2s; cursor:pointer;" onclick="document.querySelectorAll('.study-item').forEach(el=>el.classList.remove('active','border-primary','bg-primary-subtle')); this.classList.add('active','border-primary','bg-primary-subtle');">
                        <div class="card-body p-2 p-md-3">
                            <div class="d-flex justify-content-between align-items-start mb-2">
                                <span class="fw-bold text-dark font-poppins" style="font-size: 0.85rem; color: #115e59 !important;">${est.descripcion}</span>
                                <button class="btn btn-sm text-danger p-0 ms-2" onclick="event.stopPropagation(); VisorApp.eliminarEstudioVisor('${est.id_estudio}')" title="Eliminar Estudio Completo">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                            <div class="text-uppercase small mb-2 text-muted fw-bold" style="font-size: 0.7rem; letter-spacing: 0.5px;">
                                Ref: ${est.modalidad}-${est.id_estudio} &bull; ${est.fecha}
                            </div>
                            <div class="d-flex flex-wrap gap-2">
                                ${thumbsHtml}
                            </div>
                        </div>
                    </div>
                </div>
                `;

            });



            const dataList = document.getElementById('lista-estudios');

            if (dataList) dataList.innerHTML = dataListOptions;

        }



        if (seriesContainerDynamic) {

            seriesContainerDynamic.innerHTML = htmlEstudios;

        }



        if (this.estudios.length > 0) {

            const urlParams = new URLSearchParams(window.location.search);

            const targetId = urlParams.get('estudio_id');

            let targetEstudio = this.estudios[0];

            

            if (targetId) {

                const found = this.estudios.find(e => e.id_estudio == targetId);

                if (found) targetEstudio = found;

            }

            

            // Load first image of the target study if it exists

            if (targetEstudio.imagenes && targetEstudio.imagenes.length > 0) {

                let safeRuta = targetEstudio.imagenes[0].ruta.replace(/\\/g, '/');

                this.loadSerie(safeRuta, null);

            }

        }

    },



    eliminarEstudioVisor: function(id) {
        console.log("[DEBUG] eliminarEstudioVisor invocado para id:", id);
        if (!id) {
            console.error("[DEBUG] Error: id de estudio es indefinido.");
        }
        Swal.fire({
            title: 'Eliminar Estudio?',
            text: 'Esta accion eliminara el estudio seleccionado.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            confirmButtonText: 'Si, eliminar',
cancelButtonText: 'Cancelar'
        }).then((result) => {
            console.log("[DEBUG] Swal.fire (estudio) result:", result);
            if (result.isConfirmed) {
                console.log("[DEBUG] Enviando POST a delete_estudio_api.pl con id:", id);
                axios.post('../api/delete_estudio_api.pl', new URLSearchParams({id_estudio: id}))
                .then(res => {
                    console.log("[DEBUG] Respuesta server delete_estudio:", res.data);
                    if(res.data.ok) {
                        Swal.fire('Eliminado', 'El estudio ha sido borrado.', 'success').then(() => {
                            location.reload();
                        });
                    } else {
                        console.error("[DEBUG] Server devolvio error:", res.data.msg);
                        Swal.fire('Error', res.data.msg, 'error');
                    }
                })
                .catch(err => {
                    console.error("[DEBUG] Axios error en delete_estudio:", err);
                    Swal.fire('Error', 'Error de red o servidor.', 'error');
                });
            } else {
                console.log("[DEBUG] Cancelado por el usuario.");
            }
        });
    },



    eliminarImagenVisor: function(id_estudio, id_imagen) {
        console.log("[DEBUG] eliminarImagenVisor invocado. id_estudio:", id_estudio, "id_imagen:", id_imagen);
        Swal.fire({
            title: 'Eliminar Imagen?',
            text: 'Esta accion eliminara la imagen del estudio.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            confirmButtonText: 'Si, eliminar',
cancelButtonText: 'Cancelar'
        }).then((result) => {
            console.log("[DEBUG] Swal.fire (imagen) result:", result);
            if (result.isConfirmed) {
                console.log("[DEBUG] Enviando POST a delete_imagen_api.pl con:", {id_estudio, id_imagen});
                axios.post('../api/delete_imagen_api.pl', new URLSearchParams({id_estudio: id_estudio, id_imagen: id_imagen}))
                .then(res => {
                    console.log("[DEBUG] Respuesta server delete_imagen:", res.data);
                    if(res.data.ok) {
                        Swal.fire('Eliminada', 'La imagen ha sido borrada.', 'success').then(() => {
                            let prom = this.loadEstudios();
                            if (prom && prom.then) {
                                prom.then(() => {
                                    let targetEstudio = this.estudios.find(e => e.id_estudio == id_estudio);
                                    if (targetEstudio && targetEstudio.imagenes && targetEstudio.imagenes.length > 0) {
                                        let firstImg = targetEstudio.imagenes[0].ruta.replace(/\\/g, '/');
                                        this.loadSerie(firstImg, null);
                                    } else {
                                        location.reload();
                                    }
                                });
                            } else {
                                location.reload();
                            }
                        });
                    } else {
                        console.error("[DEBUG] Server devolvio error:", res.data.msg);
                        Swal.fire('Error', res.data.msg, 'error');
                    }
                })
                .catch(err => {
                    console.error("[DEBUG] Axios error en delete_imagen:", err);
                    Swal.fire('Error', 'Error de red o servidor.', 'error');
                });
            } else {
                console.log("[DEBUG] Cancelado por el usuario.");
            }
        });
    },



    loadSerie: function(ruta, element, isLocalObjectURL = false) {

        if (element) {

            document.querySelectorAll('.study-item').forEach(el => {

                el.classList.remove('border-primary', 'border-2', 'bg-primary-subtle');

                el.classList.add('border', 'bg-white', 'shadow-sm');

            });

            element.classList.remove('border', 'bg-white', 'shadow-sm');

            element.classList.add('border-primary', 'border-2', 'bg-primary-subtle');

        }



        const seriesNav = document.querySelector('.series-nav-horizontal');
        if (seriesNav) {
            if (isLocalObjectURL) {
                const deleteBtnHtml = `<button class="btn btn-sm btn-danger position-absolute top-0 end-0 p-0 shadow rounded-circle d-flex align-items-center justify-content-center" style="width:20px;height:20px;margin-top:-5px;margin-right:-5px;" onclick="VisorApp.removeLocalThumb(this)"><i class="bi bi-x"></i></button>`;
                seriesNav.innerHTML = `
                    <div class="position-relative me-2 d-inline-block flex-shrink-0" style="width: 80px; height: 80px;">
                        <div class="series-thumb-btn active border-primary border-3 position-relative w-100 h-100 rounded bg-dark overflow-hidden">
                            <img src="${ruta}" class="w-100 h-100 object-fit-cover" onerror="this.onerror=null; VisorApp.renderDicomThumbnail(this, '${ruta}');">
                            <span class="img-count position-absolute bottom-0 end-0 bg-primary text-white px-2 py-1 shadow small fw-bold" style="font-size: 0.7rem;">1</span>
                        </div>
                        ${deleteBtnHtml}
                    </div>
                `;
            } else {
                let targetEstudio = this.estudios.find(e => 
                    (e.imagenes && e.imagenes.some(img => img.ruta.replace(/\\/g, '/') === ruta)) || 
                    (e.ruta && e.ruta.replace(/\\/g, '/') === ruta)
                );

                if (targetEstudio) {
                    this.currentSerieDesc = targetEstudio.descripcion;
                    let thumbsHtml = '';
                    
                    if (targetEstudio.imagenes && targetEstudio.imagenes.length > 0) {
                        this.currentSerieLength = targetEstudio.imagenes.length;
                        targetEstudio.imagenes.forEach((img, i) => {
                            const safeRuta = img.ruta.replace(/\\/g, '/');
                            if (safeRuta === ruta) this.currentImageIndex = i + 1;
                            
                            let thumbUrl = "";
                            if (safeRuta.startsWith('dat/')) {
                                thumbUrl = `../api/read_estudio_api.pl?ruta=${encodeURIComponent(safeRuta)}`;
                            } else if (safeRuta.startsWith('/')) {
                                thumbUrl = ".." + safeRuta;
                            } else {
                                thumbUrl = "../" + safeRuta;
                            }
                            const activeClass = safeRuta === ruta ? 'active border-primary border-3' : 'opacity-50';
                            
                            const deleteBtn = `<button class="btn btn-sm btn-danger position-absolute top-0 end-0 p-0 shadow rounded-circle d-flex align-items-center justify-content-center" style="width:20px;height:20px;margin-top:-5px;margin-right:-5px;" onclick="event.stopPropagation(); VisorApp.eliminarImagenVisor('${targetEstudio.id_estudio}', '${img.id_imagen}')" title="Eliminar Imagen"><i class="bi bi-trash"></i></button>`;
                            
                            thumbsHtml += `
                                <div class="position-relative me-2 d-inline-block flex-shrink-0" style="width: 80px; height: 80px; cursor: pointer;" onclick="VisorApp.loadSerie('${safeRuta}', null)">
                                    <div class="series-thumb-btn ${activeClass} w-100 h-100 rounded bg-dark position-relative overflow-hidden">
                                        <img src="${thumbUrl}" class="w-100 h-100 object-fit-cover" onerror="this.onerror=null; VisorApp.renderDicomThumbnail(this, '${safeRuta}');">
                                        <span class="img-count position-absolute bottom-0 end-0 ${safeRuta === ruta ? 'bg-primary text-white shadow fw-bold' : 'bg-dark text-white'} px-2 py-1" style="font-size: 0.7rem;">${i+1}</span>
                                    </div>
                                    <button class="btn btn-sm btn-danger position-absolute top-0 end-0 p-0 shadow rounded-circle d-flex align-items-center justify-content-center" style="width:20px;height:20px;margin-top:-5px;margin-right:-5px; z-index: 50;" onclick="event.stopPropagation(); VisorApp.eliminarImagenVisor('${targetEstudio.id_estudio}', '${img.id_imagen}')" title="Eliminar Imagen"><i class="bi bi-trash"></i></button>
                                </div>
                            `;
                        });
                    } else {
                        this.currentSerieLength = 1;
                        this.currentImageIndex = 1;
                        const safeRuta = targetEstudio.ruta.replace(/\\/g, '/');
                        let thumbUrl = "";
                        if (safeRuta.startsWith('dat/')) {
                            thumbUrl = `../api/read_estudio_api.pl?ruta=${encodeURIComponent(safeRuta)}`;
                        } else if (safeRuta.startsWith('/')) {
                            thumbUrl = ".." + safeRuta;
                        } else {
                            thumbUrl = "../" + safeRuta;
                        }
                        thumbsHtml += `
                            <div class="position-relative me-2 d-inline-block flex-shrink-0" style="width: 80px; height: 80px;">
                                <div class="series-thumb-btn active border-primary border-3 w-100 h-100 rounded bg-dark position-relative overflow-hidden">
                                    <img src="${thumbUrl}" class="w-100 h-100 object-fit-cover" onerror="this.onerror=null; VisorApp.renderDicomThumbnail(this, '${safeRuta}');">
                                    <span class="img-count position-absolute bottom-0 end-0 bg-primary text-white px-2 py-1 shadow fw-bold" style="font-size: 0.7rem;">1</span>
                                </div>
                            </div>
                        `;
                    }
                    seriesNav.innerHTML = thumbsHtml;
                }
            }
        }



        this.renderImageToCanvas(ruta, isLocalObjectURL);

    },



    removeLocalThumb: function(btn) {

        if(btn && btn.parentElement) btn.parentElement.remove();

        this.currentFile = null;

        if(this.imageWrapper) this.imageWrapper.style.backgroundImage = 'none';

        

        const uploadFile = document.getElementById('uploadFile');

        if (uploadFile) uploadFile.value = '';

    },



    renderImageToCanvas: function(ruta, isLocalObjectURL) {

        if (!this.element) return;

        

        let url = ruta;

        if (!isLocalObjectURL) {

            if (ruta.startsWith('/')) {

                url = ".." + ruta; // Relative to root

            } else {

                url = "../" + ruta;

            }

            

            if (ruta.startsWith('dat/')) {

                url = `../api/read_estudio_api.pl?ruta=${encodeURIComponent(ruta)}`;

            }

            

            // Convert to absolute URL. Cornerstone WADO Web Workers fail with relative paths.

            url = window.location.origin + window.location.pathname.replace('render_visor_medico.pl', '') + url;

        }

        

        let imageId = url;

        if (isLocalObjectURL && this.currentFile) {

            if (this.currentFile.name.toLowerCase().endsWith('.dcm')) {

                imageId = cornerstoneWADOImageLoader.wadouri.fileManager.add(this.currentFile);

            }

        } else if (!isLocalObjectURL && ruta.toLowerCase().endsWith('.dcm')) {

            imageId = "wadouri:" + url;

        }



        console.log("Cargando imagen en Cornerstone:", imageId);

        

        const loadingSpinner = document.getElementById('dicomLoading');

        if(loadingSpinner) loadingSpinner.classList.remove('d-none');



        cornerstone.loadImage(imageId).then((image) => {

            cornerstone.displayImage(this.element, image);

            cornerstone.reset(this.element);

            if(loadingSpinner) loadingSpinner.classList.add('d-none');

            

            // Si es JPG/PNG, advertir que las medidas estan en pixeles.

            if (!ruta.toLowerCase().endsWith('.dcm')) {

                console.log("Renderizado mediante Cornerstone Web Image Loader (Sin Metadata DICOM)");

            }

        }).catch(err => {

            console.error("Error cargoando la imagen con Cornerstone:", err);

            if(loadingSpinner) loadingSpinner.classList.add('d-none');

            Swal.fire('Error', 'No se pudo renderizar la imagen medica.', 'error');

        });

    },



    guardarEstudio: function(e) {

        e.preventDefault();

        const btnSubmit = document.getElementById('btn-submit-estudio');

        if(!btnSubmit) return;

        

        const uploadFile = document.getElementById('uploadFile');

        if (!uploadFile.files.length) {

            Swal.fire('Atencion', 'Por favor seleccione un archivo para subir.', 'warning');

            return;

        }



        const destino = document.getElementById('uploadDestino').value;

        const nombre = document.getElementById('input-nombre-estudio').value;

        const modalidad = document.getElementById('uploadModalidad').value;



        if (destino === 'nuevo' && !nombre.trim()) {

            Swal.fire('Atencion', 'El nombre de estudio es obligatorio para nuevos estudios.', 'warning');

            return;

        }



        btnSubmit.disabled = true;

        btnSubmit.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span> Subiendo...';



        const formData = new FormData();

        formData.append('id_paciente', window.ID_PACIENTE);

        formData.append('notas', '');

        formData.append('archivo_estudio', uploadFile.files[0]);



        if (destino !== 'nuevo') {

            formData.append('id_estudio', destino);

        } else {

            formData.append('nombre_estudio', nombre);

            formData.append('modalidad', modalidad);

        }



        axios.post('../api/guardar_estudio_api.pl', formData, {

            headers: { 'Content-Type': 'multipart/form-data' }

        })

        .then(response => {

            if (response.data.ok) {

                bootstrap.Modal.getInstance(document.getElementById('modalGuardarEstudio')).hide();

                Swal.fire('Guardado', response.data.msg || 'La imagen se cargo exitosamente al estudio.', 'success');

                // Limpiar form

                uploadFile.value = '';

                document.getElementById('input-nombre-estudio').value = '';

                document.getElementById('uploadDestino').value = 'nuevo';

                document.getElementById('nuevo-estudio-fields').style.display = 'block';



                this.loadEstudios(); // Recargoo el sidebar

            } else {

                Swal.fire('Error', response.data.msg || 'Ocurrio un error al guardar', 'error');

            }

        })

        .catch(err => {

            console.error(err);

            Swal.fire('Error', 'Fallo en el servidor o timeout.', 'error');

        })

        .finally(() => {

            btnSubmit.disabled = false;

            btnSubmit.innerHTML = 'Subir Archivo <i class="bi bi-cloud-upload ms-1"></i>';

        });

    },



    toggleSidebar: function(side) {

        const sidebar = document.querySelector(`.visor-sidebar-${side}`);

        if (sidebar) {

            sidebar.classList.toggle('d-none');

            // Trigger a resize event to ensure canvas or any other responsive elements adjust

            setTimeout(() => window.dispatchEvent(new Event('resize')), 300);

        }

    }

};



document.addEventListener('DOMContentLoaded', () => {

    VisorApp.init();

});







