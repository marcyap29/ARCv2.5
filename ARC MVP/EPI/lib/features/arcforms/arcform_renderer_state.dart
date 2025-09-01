import 'package:equatable/equatable.dart';

abstract class ArcformRendererState extends Equatable {
  const ArcformRendererState();

  @override
  List<Object> get props => [];
}

class ArcformRendererInitial extends ArcformRendererState {
  const ArcformRendererInitial();
}

class ArcformRendererLoading extends ArcformRendererState {
  const ArcformRendererLoading();
}

class ArcformRendererLoaded extends ArcformRendererState {
  final List<Node> nodes;
  final List<Edge> edges;
  final GeometryPattern selectedGeometry;

  const ArcformRendererLoaded({
    required this.nodes,
    required this.edges,
    required this.selectedGeometry,
  });

  @override
  List<Object> get props => [nodes, edges, selectedGeometry];

  ArcformRendererLoaded copyWith({
    List<Node>? nodes,
    List<Edge>? edges,
    GeometryPattern? selectedGeometry,
  }) {
    return ArcformRendererLoaded(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      selectedGeometry: selectedGeometry ?? this.selectedGeometry,
    );
  }
}

class ArcformRendererError extends ArcformRendererState {
  final String message;

  const ArcformRendererError(this.message);

  @override
  List<Object> get props => [message];
}

class Node {
  final String id;
  final String label;
  final double x;
  final double y;
  final double size;

  Node({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    this.size = 20.0,
  });
}

class Edge {
  final String source;
  final String target;

  Edge({
    required this.source,
    required this.target,
  });
}

enum GeometryPattern {
  spiral,
  flower,
  branch,
  weave,
  glowCore,
  fractal,
}

extension GeometryPatternExtension on GeometryPattern {
  String get displayName {
    switch (this) {
      case GeometryPattern.spiral:
        return 'Discovery';
      case GeometryPattern.flower:
        return 'Expansion';
      case GeometryPattern.branch:
        return 'Transition';
      case GeometryPattern.weave:
        return 'Consolidation';
      case GeometryPattern.glowCore:
        return 'Recovery';
      case GeometryPattern.fractal:
        return 'Breakthrough';
    }
  }

  String get description {
    switch (this) {
      case GeometryPattern.spiral:
        return 'Exploring new insights and beginnings';
      case GeometryPattern.flower:
        return 'Expanding awareness and growth';
      case GeometryPattern.branch:
        return 'Navigating transitions and choices';
      case GeometryPattern.weave:
        return 'Integrating experiences and wisdom';
      case GeometryPattern.glowCore:
        return 'Healing and restoring balance';
      case GeometryPattern.fractal:
        return 'Breaking through to new levels';
    }
  }
}
