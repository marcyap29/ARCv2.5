import 'package:flutter/material.dart';
// import 'package:my_app/mira/store/mcp/migration/photo_migration_service.dart'; // TODO: Not yet implemented
import 'package:my_app/arc/core/journal_repository.dart';

/// Placeholder classes for photo migration (to be implemented)
class PhotoMigrationService {
  final JournalRepository journalRepository;
  final String outputDir;

  PhotoMigrationService({
    required this.journalRepository,
    required this.outputDir,
  });

  Future<PhotoMigrationAnalysis> analyzeMigration() async {
    // TODO: Implement actual analysis
    return PhotoMigrationAnalysis(
      totalPhotos: 0,
      migratedPhotos: 0,
      failedPhotos: 0,
      totalSizeBytes: 0,
      migratedSizeBytes: 0,
      errors: [],
      totalEntries: 0,
      entriesWithMedia: 0,
      totalMedia: 0,
      photoLibraryMedia: 0,
      filePathMedia: 0,
      networkMedia: 0,
    );
  }

  Future<PhotoMigrationResult> migrateAllEntries({
    required Function(int, int) onProgress,
  }) async {
    // TODO: Implement actual migration
    return PhotoMigrationResult(
      migratedEntries: 0,
      migratedMedia: 0,
      errors: [],
    );
  }
}

class PhotoMigrationResult {
  final int migratedEntries;
  final int migratedMedia;
  final List<String> errors;
  final String? journalPath;
  final List<String> mediaPackPaths;

  PhotoMigrationResult({
    required this.migratedEntries,
    required this.migratedMedia,
    required this.errors,
    this.journalPath,
    this.mediaPackPaths = const [],
  });
}

class PhotoMigrationAnalysis {
  final int totalPhotos;
  final int migratedPhotos;
  final int failedPhotos;
  final int totalSizeBytes;
  final int migratedSizeBytes;
  final List<String> errors;
  final int totalEntries;
  final int entriesWithMedia;
  final int totalMedia;
  final int photoLibraryMedia;
  final int filePathMedia;
  final int networkMedia;

  PhotoMigrationAnalysis({
    required this.totalPhotos,
    required this.migratedPhotos,
    required this.failedPhotos,
    required this.totalSizeBytes,
    required this.migratedSizeBytes,
    required this.errors,
    required this.totalEntries,
    required this.entriesWithMedia,
    required this.totalMedia,
    required this.photoLibraryMedia,
    required this.filePathMedia,
    required this.networkMedia,
  });
}

/// Dialog for migrating photos from ph:// to content-addressed (SHA-256) format
class PhotoMigrationDialog extends StatefulWidget {
  final JournalRepository journalRepository;
  final String outputDir;

  const PhotoMigrationDialog({
    super.key,
    required this.journalRepository,
    required this.outputDir,
  });

  @override
  State<PhotoMigrationDialog> createState() => _PhotoMigrationDialogState();
}

class _PhotoMigrationDialogState extends State<PhotoMigrationDialog> {
  late PhotoMigrationService _migrationService;

  // States
  bool _isAnalyzing = true;
  bool _isMigrating = false;
  bool _isComplete = false;
  String? _error;

  // Analysis results
  PhotoMigrationAnalysis? _analysis;

  // Migration progress
  int _processedEntries = 0;
  int _processedMedia = 0;
  int _totalEntries = 0;
  int _totalMedia = 0;
  List<String> _errors = [];
  DateTime? _startTime;
  String? _journalPath;
  List<String> _mediaPackPaths = [];

  @override
  void initState() {
    super.initState();
    _migrationService = PhotoMigrationService(
      journalRepository: widget.journalRepository,
      outputDir: widget.outputDir,
    );
    _analyzeEntries();
  }

  Future<void> _analyzeEntries() async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final analysis = await _migrationService.analyzeMigration();

      if (mounted) {
        setState(() {
          _analysis = analysis;
          _totalEntries = analysis.entriesWithMedia;
          _totalMedia = analysis.totalMedia;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _error = null;
      _startTime = DateTime.now();
      _processedEntries = 0;
      _processedMedia = 0;
      _errors = [];
    });

    try {
      final result = await _migrationService.migrateAllEntries(
        onProgress: (processed, total) {
          if (mounted) {
            setState(() {
              _processedEntries = processed;
              _processedMedia = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isMigrating = false;
          _isComplete = true;
          _processedEntries = result.migratedEntries;
          _processedMedia = result.migratedMedia;
          _errors = result.errors;
          _journalPath = result.journalPath;
          _mediaPackPaths = result.mediaPackPaths;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isMigrating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Content
            Expanded(
              child: _buildContent(),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.transform, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Photo Migration',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_isMigrating)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isAnalyzing) {
      return _buildAnalyzingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_isComplete) {
      return _buildCompleteState();
    }

    if (_isMigrating) {
      return _buildMigratingState();
    }

    return _buildAnalysisResultsState();
  }

  Widget _buildAnalyzingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing journal entries...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Migration Error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isAnalyzing = true;
                });
                _analyzeEntries();
              },
              child: const Text('Retry Analysis'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResultsState() {
    if (_analysis == null) return const SizedBox();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary card
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Migration Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStat('Total Entries', _analysis!.totalEntries.toString()),
                  _buildStat('Entries with Media', _analysis!.entriesWithMedia.toString()),
                  _buildStat('Total Photos', _analysis!.totalMedia.toString()),
                  const Divider(height: 24),
                  _buildStat('Photo Library (ph://)', _analysis!.photoLibraryMedia.toString()),
                  _buildStat('File Paths', _analysis!.filePathMedia.toString()),
                  _buildStat('Network URLs', _analysis!.networkMedia.toString()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // What will happen
          const Text(
            'What will happen:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildBulletPoint('Fetch original photo bytes from Photo Library'),
          _buildBulletPoint('Compute SHA-256 hash for each photo'),
          _buildBulletPoint('Re-encode photos (strip EXIF for privacy)'),
          _buildBulletPoint('Generate thumbnails for journal'),
          _buildBulletPoint('Create monthly media packs'),
          _buildBulletPoint('Update entries with content-addressed references'),

          if (_analysis!.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Warnings',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._analysis!.errors.map((error) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $error', style: const TextStyle(fontSize: 12)),
                        )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMigratingState() {
    final progress = _totalMedia > 0 ? _processedMedia / _totalMedia : 0.0;
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!) : Duration.zero;
    final remaining = _calculateRemainingTime(progress, elapsed);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Progress circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[200],
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Linear progress
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
          ),

          const SizedBox(height: 24),

          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildProgressStat(
                  'Entries',
                  '$_processedEntries / $_totalEntries',
                  Icons.description,
                ),
              ),
              Expanded(
                child: _buildProgressStat(
                  'Photos',
                  '$_processedMedia / $_totalMedia',
                  Icons.photo,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildProgressStat(
                  'Elapsed',
                  _formatDuration(elapsed),
                  Icons.access_time,
                ),
              ),
              Expanded(
                child: _buildProgressStat(
                  'Remaining',
                  remaining,
                  Icons.hourglass_empty,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Current action
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Processing photos...'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // Success icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: 60,
              color: Colors.green[600],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Migration Complete!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
          ),

          const SizedBox(height: 24),

          // Results
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildResultRow('Migrated Entries', _processedEntries.toString()),
                  _buildResultRow('Migrated Photos', _processedMedia.toString()),
                  if (_journalPath != null)
                    _buildResultRow('Journal', _journalPath!, monospace: true),
                  if (_mediaPackPaths.isNotEmpty)
                    _buildResultRow(
                      'Media Packs',
                      '${_mediaPackPaths.length} pack(s) created',
                    ),
                ],
              ),
            ),
          ),

          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          '${_errors.length} Warning(s)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._errors.take(5).map((error) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $error', style: const TextStyle(fontSize: 12)),
                        )),
                    if (_errors.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '... and ${_errors.length - 5} more',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Media pack locations
          if (_mediaPackPaths.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Media Pack Locations:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ..._mediaPackPaths.map((path) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_zip, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          path,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!_isMigrating && !_isComplete) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _analysis != null && _analysis!.entriesWithMedia > 0
                  ? _startMigration
                  : null,
              child: const Text('START MIGRATION'),
            ),
          ],
          if (_isComplete)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue[700]),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool monospace = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: monospace ? 'monospace' : null,
                fontSize: monospace ? 11 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  String _calculateRemainingTime(double progress, Duration elapsed) {
    if (progress <= 0) return '~calculating...';
    if (progress >= 1.0) return '0m 0s';

    final totalTime = elapsed.inSeconds / progress;
    final remaining = totalTime - elapsed.inSeconds;

    final minutes = (remaining / 60).floor();
    final seconds = (remaining % 60).floor();

    return '~${minutes}m ${seconds}s';
  }
}
