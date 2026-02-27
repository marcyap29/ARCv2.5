import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: NativeBridgeTest(),
    );
  }
}

class NativeBridgeTest extends StatefulWidget {
  const NativeBridgeTest({super.key});

  @override
  _NativeBridgeTestState createState() => _NativeBridgeTestState();
}

class _NativeBridgeTestState extends State<NativeBridgeTest> {
  String _result = 'Not tested yet';
  
  static const MethodChannel _channel = MethodChannel('lumara_llm');
  
  Future<void> _testNativeBridge() async {
    try {
      print('Testing native bridge...');
      
      // Test ping
      final pong = await _channel.invokeMethod<String>('ping');
      print('Ping result: $pong');
      
      // Test selfTest
      final diag = await _channel.invokeMethod('selfTest');
      print('SelfTest result: $diag');
      
      setState(() {
        _result = 'Success!\nPing: $pong\nSelfTest: $diag';
      });
    } catch (e) {
      print('Error: $e');
      setState(() {
        _result = 'Error: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native Bridge Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Native Bridge Test', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            Text(_result, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testNativeBridge,
              child: const Text('Test Native Bridge'),
            ),
          ],
        ),
      ),
    );
  }
}
