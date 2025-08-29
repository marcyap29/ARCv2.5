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
        return 'Spiral';
      case GeometryPattern.flower:
        return 'Flower';
      case GeometryPattern.branch:
        return 'Branch';
      case GeometryPattern.weave:
        return 'Weave';
      case GeometryPattern.glowCore:
        return 'Glow Core';
      case GeometryPattern.fractal:
        return 'Fractal';
    }
  }

  String get description {
    switch (this) {
      case GeometryPattern.spiral:
        return 'Nodes arranged in a spiral pattern';
      case GeometryPattern.flower:
        return 'Nodes arranged like petals of a flower';
      case GeometryPattern.branch:
        return 'Nodes arranged in branching patterns';
      case GeometryPattern.weave:
        return 'Nodes arranged in interconnected weave';
      case GeometryPattern.glowCore:
        return 'Nodes arranged around a central core';
      case GeometryPattern.fractal:
        return 'Nodes arranged in fractal patterns';
    }
  }
}
