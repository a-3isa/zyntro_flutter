import 'migration_lifecycle.dart';

class LayerContract {
  final String contractId;
  final String sliceId;
  final LayerBoundary layerBoundary;
  final List<String> inboundExpectations;
  final List<String> outboundGuarantees;
  final bool approved;

  const LayerContract({
    required this.contractId,
    required this.sliceId,
    required this.layerBoundary,
    required this.inboundExpectations,
    required this.outboundGuarantees,
    required this.approved,
  });

  LayerContract copyWith({
    String? contractId,
    String? sliceId,
    LayerBoundary? layerBoundary,
    List<String>? inboundExpectations,
    List<String>? outboundGuarantees,
    bool? approved,
  }) {
    return LayerContract(
      contractId: contractId ?? this.contractId,
      sliceId: sliceId ?? this.sliceId,
      layerBoundary: layerBoundary ?? this.layerBoundary,
      inboundExpectations: inboundExpectations ?? this.inboundExpectations,
      outboundGuarantees: outboundGuarantees ?? this.outboundGuarantees,
      approved: approved ?? this.approved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contractId': contractId,
      'sliceId': sliceId,
      'layerBoundary': layerBoundary.wireValue,
      'inboundExpectations': inboundExpectations,
      'outboundGuarantees': outboundGuarantees,
      'approved': approved,
    };
  }

  factory LayerContract.fromMap(Map<String, dynamic> map) {
    return LayerContract(
      contractId: map['contractId'] as String,
      sliceId: map['sliceId'] as String,
      layerBoundary: LayerBoundaryX.fromWireValue(
        map['layerBoundary'] as String,
      ),
      inboundExpectations: (map['inboundExpectations'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      outboundGuarantees: (map['outboundGuarantees'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      approved: map['approved'] as bool? ?? false,
    );
  }
}
