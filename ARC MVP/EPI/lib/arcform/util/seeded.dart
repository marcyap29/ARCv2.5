// lib/arcform/util/seeded.dart
// Deterministic random number generator for reproducible ARCForm variations

import 'dart:math' as math;

/// A simple deterministic RNG using xorshift algorithm
/// Same seed always produces the same sequence of random numbers
class Seeded {
  int _state;

  /// Initialize RNG with a string seed
  Seeded(String seed) : _state = seed.hashCode ^ 0x9E3779B9;

  /// Initialize RNG with an integer seed
  Seeded.fromInt(int seed) : _state = seed ^ 0x9E3779B9;

  /// Generate next random integer
  int nextInt() {
    var x = _state;
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    _state = x;
    return x & 0x7fffffff;
  }

  /// Generate random double in range [0, 1)
  double nextDouble() => nextInt() / 0x7fffffff;

  /// Generate random double in range [min, max)
  double nextRange(double min, double max) {
    return min + nextDouble() * (max - min);
  }

  /// Generate random boolean
  bool nextBool() => nextInt() & 1 == 1;

  /// Generate random integer in range [min, max) (exclusive max)
  int nextIntRange(int min, int max) {
    return min + (nextInt() % (max - min));
  }

  /// Generate random value with Gaussian distribution (mean=0, stddev=1)
  double nextGaussian() {
    // Box-Muller transform
    final u1 = nextDouble();
    final u2 = nextDouble();
    final r = math.sqrt(-2.0 * math.log(u1 > 0 ? u1 : 0.0001));
    final theta = 2.0 * 3.14159265359 * u2;
    return r * math.cos(theta);
  }

  /// Generate random point on unit sphere using Marsaglia's method
  ({double x, double y, double z}) nextUnitSphere() {
    double x, y, z, s;
    do {
      x = nextRange(-1, 1);
      y = nextRange(-1, 1);
      z = nextRange(-1, 1);
      s = x * x + y * y + z * z;
    } while (s > 1.0 || s == 0.0);
    
    final invSqrt = 1.0 / math.sqrt(s);
    return (x: x * invSqrt, y: y * invSqrt, z: z * invSqrt);
  }

  /// Shuffle a list in-place using Fisher-Yates algorithm
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = nextIntRange(0, i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }

  /// Pick a random element from a list
  T pick<T>(List<T> list) {
    return list[nextIntRange(0, list.length)];
  }

  /// Reset the RNG to its initial state
  void reset(String seed) {
    _state = seed.hashCode ^ 0x9E3779B9;
  }

  /// Create a child RNG with a derived seed
  Seeded derive(String suffix) {
    return Seeded('${_state}:$suffix');
  }
}

