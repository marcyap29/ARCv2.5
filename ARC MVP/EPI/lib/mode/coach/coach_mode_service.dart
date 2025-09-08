import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'coach_mode_cubit.dart';
import 'coach_droplet_service.dart';
import 'coach_share_service.dart';

class CoachModeService {
  static CoachModeService? _instance;
  static CoachModeService get instance => _instance ??= CoachModeService._internal();

  CoachModeService._internal();

  late final CoachDropletService _dropletService;
  late final CoachShareService _shareService;
  late final CoachModeCubit _cubit;
  late final Box _settingsBox;
  late final Box _dropletTemplatesBox;
  late final Box _dropletResponsesBox;
  late final Box _shareBundlesBox;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive boxes
      _settingsBox = await Hive.openBox('settings');
      _dropletTemplatesBox = await Hive.openBox('coach_droplet_templates');
      _dropletResponsesBox = await Hive.openBox('coach_droplet_responses');
      _shareBundlesBox = await Hive.openBox('coach_share_bundles');

      // Initialize services
      _dropletService = CoachDropletService(
        dropletTemplatesBox: _dropletTemplatesBox,
        dropletResponsesBox: _dropletResponsesBox,
        uuid: const Uuid(),
      );

      _shareService = CoachShareService(
        dropletService: _dropletService,
        shareBundlesBox: _shareBundlesBox,
        uuid: const Uuid(),
      );

      // Initialize cubit
      _cubit = CoachModeCubit(
        dropletService: _dropletService,
        shareService: _shareService,
        settingsBox: _settingsBox,
        uuid: const Uuid(),
      );

      // Initialize droplet service with default templates
      await _dropletService.initialize();

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize Coach Mode Service: $e');
    }
  }

  CoachModeCubit get cubit {
    if (!_isInitialized) {
      throw Exception('CoachModeService not initialized. Call initialize() first.');
    }
    return _cubit;
  }

  CoachDropletService get dropletService {
    if (!_isInitialized) {
      throw Exception('CoachModeService not initialized. Call initialize() first.');
    }
    return _dropletService;
  }

  CoachShareService get shareService {
    if (!_isInitialized) {
      throw Exception('CoachModeService not initialized. Call initialize() first.');
    }
    return _shareService;
  }

  bool get isInitialized => _isInitialized;

  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      await _cubit.close();
      await _settingsBox.close();
      await _dropletTemplatesBox.close();
      await _dropletResponsesBox.close();
      await _shareBundlesBox.close();
      _isInitialized = false;
    } catch (e) {
      // Log error but don't throw
      print('Error disposing CoachModeService: $e');
    }
  }
}
