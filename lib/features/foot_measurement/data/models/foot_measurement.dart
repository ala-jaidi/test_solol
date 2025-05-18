class FootMeasurement {
  final double lengthCm;
  final double widthCm;

  FootMeasurement({required this.lengthCm, required this.widthCm});

  Map<String, dynamic> toJson() => {
    'lengthCm': lengthCm,
    'widthCm': widthCm,
  };

  factory FootMeasurement.fromJson(Map<String, dynamic> json) {
    return FootMeasurement(
      lengthCm: json['lengthCm'],
      widthCm: json['widthCm'],
    );
  }
}
