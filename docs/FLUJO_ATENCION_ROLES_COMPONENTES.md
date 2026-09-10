# Flujo Global de Atención Médica: Roles y Componentes

## 1. Pipeline Unificado de Atención Médica

```mermaid
graph LR
    Paso0["0. Registro Paciente<br/>(views/crud_paciente.pl)"] --> Paso1["1. Agenda / Cita<br/>(views/agenda_main.pl)"]
    Paso1 --> Paso2["2. Expediente & SOAP<br/>(views/render_consultas.pl)"]
    Paso2 --> Paso3["3. Estudios / Receta<br/>(views/render_visor_medico.pl)"]
    Paso3 --> Paso4["4. Caja & Recibo<br/>(views/generar_recibo.pl)"]
```

---

## 2. Descripción de Etapas

1. **Recepción y Agenda**: Registro de datos de identificación y asignación de turno/médico en agenda.
2. **Atención Médica SOAP**: Captura de historia clínica, signos vitales y nota SOAP polimórfica.
3. **Estudios y Auxiliares**: Solicitud de laboratorio o imagenología cargados directamente al estado de cuenta o cobrados en caja.
4. **Cierre y Recibo**: Cobro en ventanilla en **Caja Rápida**, selección de tarifas y emisión de recibo foliado.
