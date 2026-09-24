$(document).ready(function() {
  $('#tabla_citas').DataTable({
    responsive: true,
    dom: 'Bfrtip',
    buttons: [
      {
        extend: 'copy',
        text: '<i class="bi bi-clipboard"></i> Copiar',
        className: 'btn btn-outline-secondary btn-sm'
      },
      {
        extend: 'excel',
        text: '<i class="bi bi-file-earmark-excel"></i> Excel',
        className: 'btn btn-outline-success btn-sm'
      },
      {
        extend: 'pdf',
        text: '<i class="bi bi-file-earmark-pdf"></i> PDF',
        className: 'btn btn-outline-danger btn-sm'
      },
      {
        extend: 'print',
        text: '<i class="bi bi-printer"></i> Imprimir',
        className: 'btn btn-outline-primary btn-sm'
      }
    ],
    language: {
      url: "//cdn.datatables.net/plug-ins/1.13.6/i18n/es-MX.json"
    }
  });
});
