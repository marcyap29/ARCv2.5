/// ARCX Import Progress Screen
/// 
/// Fullscreen modal showing import progress with status updates.
library arcx_import_progress;

import 'package:flutter/material.dart';
import '../../shared/app_colors.dart';
import '../../shared/text_style.dart';
import '../services/arcx_import_service.dart';
import '../services/arcx_crypto_service.dart';

class ARCXImportProgressScreen extends StatefulWidget {
  final String arcxPath;
  final String? manifestPath;
  
  const ARCXImportProgressScreen({
    super.key,
    required this.arcxPath,
    this.manifestPath,
  });

  @override
  State<ARCXImportProgressScreen> createState() => _ARCXImportProgressScreenState();
}

class _ARCXImportProgressScreenState extends State<ARCXImportProgressScreen> {
  String _status = 'Verifying signature...';
  bool _isLoading = true;
  String? _error;
  int? _entriesImported;
  int? _photosImported;

  @override
  void initState() {
    super.initState();
    _import();
  }

  Future<void> _import() async {
    try {
      setState(() => _status = 'Verifying signature...');
      
      final importService = ARCXImportService();
      
      setState(() => _status = 'Decrypting...');
      
      final result = await importService.importSecure(
        arcxPath: widget.arcxPath,
        manifestPath: widget.manifestPath,
        dryRun: false,
      );
      
      if (result.success) {
        setState(() {
          _isLoading = false;
          _status = 'Done';
          _entriesImported = result.entriesImported;
          _photosImported = result.photosImported;
        });
        
        // Show success message
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported ${result.entriesImported ?? 0} entries'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result.error ?? 'Import failed');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
        _status = 'Failed';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        title: Text(
          'Importing Secure Archive',
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kcPrimaryTextColor),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(kcPrimaryColor),
                ),
                const SizedBox(height: 32),
                Text(
                  _status,
                  style: heading3Style(context).copyWith(
                    color: kcPrimaryTextColor,
                  ),
                ),
              ] else if (_error != null) ...[
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import Failed',
                  style: heading2Style(context).copyWith(
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: bodyStyle(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kcPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ] else ...[
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  'Import Complete',
                  style: heading2Style(context).copyWith(
                    color: Colors.green,
                  ),
                ),
                if (_entriesImported != null || _photosImported != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Entries: ${_entriesImported ?? 0}',
                    style: bodyStyle(context),
                  ),
                  if (_photosImported != null && _photosImported! > 0)
                    Text(
                      'Photos: ${_photosImported}',
                      style: bodyStyle(context),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

