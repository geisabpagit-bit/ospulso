/**
 * js/dictado_voz.js
 * Módulo de Dictado por Voz (Speech-to-Text) para Consultas Clínicas
 * Utiliza Web Speech API nativa (SpeechRecognition / webkitSpeechRecognition)
 * Cumple estándares de accesibilidad y dictado médico continuo en español (es-MX).
 */

(function(window) {
    'use strict';

    let currentRecognition = null;
    let activeBtn = null;
    let activeTextarea = null;
    let baseTextBeforeStart = '';

    /**
     * Alterna (inicia o detiene) el dictado por voz sobre el textarea especificado
     * @param {string|HTMLTextAreaElement} targetSelector Selector o elemento textarea
     * @param {HTMLElement} btnElement Botón que disparó la acción
     */
    window.toggleDictadoVoz = function(targetSelector, btnElement) {
        const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;

        if (!SpeechRec) {
            if (typeof Swal !== 'undefined') {
                Swal.fire({
                    icon: 'warning',
                    title: 'Reconocimiento de voz no compatible',
                    text: 'Tu navegador no cuenta con soporte nativo para dictado por voz. Recomendamos utilizar Google Chrome o Microsoft Edge en su versión más reciente para aprovechar esta función.',
                    confirmButtonColor: '#0A2A66'
                });
            } else {
                alert('Tu navegador no soporta reconocimiento de voz. Por favor utiliza Google Chrome o Microsoft Edge.');
            }
            return;
        }

        const textarea = typeof targetSelector === 'string' ? document.querySelector(targetSelector) : targetSelector;
        if (!textarea) {
            console.error('Campo objetivo de dictado no encontrado:', targetSelector);
            return;
        }

        // Si ya está activo el dictado en este mismo botón, detenerlo
        if (currentRecognition && activeBtn === btnElement) {
            detenerDictado();
            return;
        }

        // Si había otro dictado corriendo en otro campo, cerrarlo limpiamente
        if (currentRecognition) {
            detenerDictado();
        }

        try {
            const recognition = new SpeechRec();
            recognition.lang = 'es-MX';
            recognition.continuous = true;
            recognition.interimResults = true;
            recognition.maxAlternatives = 1;

            activeBtn = btnElement;
            activeTextarea = textarea;
            baseTextBeforeStart = textarea.value.trim();
            currentRecognition = recognition;

            const feedbackId = btnElement.getAttribute('data-feedback-id');
            const feedbackEl = feedbackId ? document.getElementById(feedbackId) : null;

            recognition.onstart = function() {
                actualizarUiGrabando(true, feedbackEl);
            };

            recognition.onresult = function(event) {
                let interimTranscript = '';
                let finalTranscript = '';

                for (let i = event.resultIndex; i < event.results.length; ++i) {
                    const transPart = event.results[i][0].transcript;
                    if (event.results[i].isFinal) {
                        finalTranscript += transPart;
                    } else {
                        interimTranscript += transPart;
                    }
                }

                if (finalTranscript) {
                    finalTranscript = finalTranscript.trim();
                    if (finalTranscript.length > 0) {
                        // Capitalizar primera letra de cada fragmento finalizado
                        finalTranscript = finalTranscript.charAt(0).toUpperCase() + finalTranscript.slice(1);
                        
                        let sep = '';
                        if (baseTextBeforeStart.length > 0) {
                            const lastChar = baseTextBeforeStart.slice(-1);
                            sep = (lastChar === '.' || lastChar === '\n' || lastChar === '!' || lastChar === '?') ? ' ' : '. ';
                        }
                        baseTextBeforeStart = baseTextBeforeStart ? (baseTextBeforeStart + sep + finalTranscript) : finalTranscript;
                        textarea.value = baseTextBeforeStart;
                    }
                } else if (interimTranscript) {
                    let sep = baseTextBeforeStart.length > 0 ? ' ' : '';
                    textarea.value = baseTextBeforeStart + sep + interimTranscript.trim();
                }

                // Notificar a autosave y listeners de cambio
                textarea.dispatchEvent(new Event('input', { bubbles: true }));
                textarea.dispatchEvent(new Event('change', { bubbles: true }));
            };

            recognition.onerror = function(event) {
                console.warn('SpeechRecognition event error:', event.error);
                if (event.error === 'not-allowed' || event.error === 'service-not-allowed') {
                    if (typeof Swal !== 'undefined') {
                        Swal.fire({
                            icon: 'error',
                            title: 'Permiso de Micrófono Denegado',
                            text: 'El navegador bloqueó el acceso al micrófono. Por favor verifique el icono de permisos en la barra de direcciones y habilite el micrófono para continuar.',
                            confirmButtonColor: '#0A2A66'
                        });
                    }
                    detenerDictado();
                } else if (event.error === 'network') {
                    if (typeof Swal !== 'undefined') {
                        Swal.fire({
                            icon: 'warning',
                            title: 'Error de Red',
                            text: 'El servicio de transcripción de voz requiere conexión a internet para procesar el audio.',
                            toast: true,
                            position: 'top-end',
                            timer: 4000,
                            showConfirmButton: false
                        });
                    }
                    detenerDictado();
                }
            };

            recognition.onend = function() {
                actualizarUiGrabando(false, feedbackEl);
                currentRecognition = null;
                activeBtn = null;
                activeTextarea = null;
            };

            recognition.start();
        } catch (err) {
            console.error('Error al iniciar SpeechRecognition:', err);
            detenerDictado();
        }
    };

    function detenerDictado() {
        if (currentRecognition) {
            try {
                currentRecognition.stop();
            } catch (e) {}
            currentRecognition = null;
        }
        if (activeBtn) {
            const feedbackId = activeBtn.getAttribute('data-feedback-id');
            const feedbackEl = feedbackId ? document.getElementById(feedbackId) : null;
            actualizarUiGrabando(false, feedbackEl);
            activeBtn = null;
        }
        activeTextarea = null;
    }

    function actualizarUiGrabando(isRecording, feedbackEl) {
        if (!activeBtn) return;

        const textSpan = activeBtn.querySelector('.btn-dictado-text');
        const iconEl = activeBtn.querySelector('i');

        if (isRecording) {
            activeBtn.classList.remove('btn-outline-primary', 'btn-outline-teal');
            activeBtn.classList.add('btn-danger', 'shadow-sm', 'pulsing-mic');
            if (iconEl) iconEl.className = 'bi bi-stop-circle-fill me-1';
            if (textSpan) textSpan.textContent = 'Detener Dictado';

            if (feedbackEl) {
                feedbackEl.classList.remove('d-none');
                feedbackEl.classList.add('d-flex');
            }
        } else {
            activeBtn.classList.remove('btn-danger', 'shadow-sm', 'pulsing-mic');
            activeBtn.classList.add('btn-outline-primary');
            if (iconEl) iconEl.className = 'bi bi-mic-fill me-1';
            if (textSpan) textSpan.textContent = 'Dictar';

            if (feedbackEl) {
                feedbackEl.classList.add('d-none');
                feedbackEl.classList.remove('d-flex');
            }
        }
    }
})(window);
