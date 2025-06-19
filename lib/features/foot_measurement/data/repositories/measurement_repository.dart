import '../models/foot_measurement.dart';

class MeasurementRepository {
  final List<FootMeasurement> _measurements = [];

  void saveMeasurement(FootMeasurement measurement) {
    _measurements.add(measurement);
  }

  List<FootMeasurement> getMeasurements() {
    return _measurements;
  }
}
