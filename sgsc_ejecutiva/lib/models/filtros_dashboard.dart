class FiltrosDashboard {
  final DateTime? fechaInicio;
  final DateTime? fechaFin;

  final int? municipioId;
  final int? prioridadId;
  final int? estatusId;
  final int? tipoApoyoId;
  final int? dependenciaId;
  final int? canalRecepcionId;

  const FiltrosDashboard({
    this.fechaInicio,
    this.fechaFin,
    this.municipioId,
    this.prioridadId,
    this.estatusId,
    this.tipoApoyoId,
    this.dependenciaId,
    this.canalRecepcionId,
  });

  FiltrosDashboard copyWith({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    int? municipioId,
    int? prioridadId,
    int? estatusId,
    int? tipoApoyoId,
    int? dependenciaId,
    int? canalRecepcionId,
  }) {
    return FiltrosDashboard(
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      municipioId: municipioId ?? this.municipioId,
      prioridadId: prioridadId ?? this.prioridadId,
      estatusId: estatusId ?? this.estatusId,
      tipoApoyoId: tipoApoyoId ?? this.tipoApoyoId,
      dependenciaId:
          dependenciaId ?? this.dependenciaId,
      canalRecepcionId:
          canalRecepcionId ?? this.canalRecepcionId,
    );
  }
}