import 'dart:async';
import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/community_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:uuid/uuid.dart';

import '../models/vacation_watch.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/address_lookup.dart';
import '../services/live_value.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/home_tone.dart';
import '../widgets/hero_header.dart';
import '../widgets/trip_widgets.dart';
import 'vacation_house_picker_screen.dart';
import 'vacation_watch_dashboard_screen.dart';

class VacationWatchScreen extends StatefulWidget {
  const VacationWatchScreen({
    super.key,
    required this.authService,
    this.repository,
    this.storageService,
    this.karmaPoints,
    this.addressLookup,
  });

  final AuthService authService;

  /// Finds the street address for a pinned spot; tests pass their own.
  final AddressLookup? addressLookup;

  /// Defaults to the Firestore-backed services. Tests pass their own.
  final VacationWatchRepository? repository;
  final StorageService? storageService;

  /// The signed-in user's karma total; defaults to their Firestore record.
  final Stream<int>? karmaPoints;

  @override
  State<VacationWatchScreen> createState() => _VacationWatchScreenState();
}

class _VacationWatchScreenState extends State<VacationWatchScreen> {
  late final VacationWatchRepository _repository =
      widget.repository ?? VacationWatchRepository();
  late final StorageService _storageService =
      widget.storageService ?? StorageService();
  // Each stream is opened once and shared, so rebuilds (such as switching
  // Neighbours / Paid Carer) and tab switches never restart them and never
  // flash back to a loading state.
  late final LiveValue<int> _karmaPoints = LiveValue(
    widget.karmaPoints ??
        FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .snapshots()
            .map((doc) => (doc.data()?['karmaPoints'] as num?)?.toInt() ?? 0),
  );
  late final LiveValue<List<VacationWatch>> _myTrips = LiveValue(
    _repository.watchOwnedBy(_currentUserId),
  );
  late final LiveValue<List<VacationWatch>> _allTrips = LiveValue(
    _repository.watchAll(),
  );
  final Map<String, LiveValue<List<WatchActivity>>> _activity = {};

  Stream<List<WatchActivity>> _activityFor(String watchId) => _activity
      .putIfAbsent(watchId, () => LiveValue(_repository.watchActivity(watchId)))
      .stream;
  final Uuid _uuid = const Uuid();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController(
    text: '8',
  );
  final TextEditingController _karmaController = TextEditingController(
    text: '10',
  );

  VacationWatchMode _mode = VacationWatchMode.neighborly;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _houseLatitude;
  double? _houseLongitude;
  bool _isSubmitting = false;
  bool _showCreateForm = false;
  bool _isLocatingHouse = false;
  bool _isFindingAddress = false;
  String? _addressError;
  late final AddressLookup _addressLookup =
      widget.addressLookup ?? AddressLookup();
  final ValueNotifier<int> _addressChanged = ValueNotifier(0);

  // Which planner fields the user has set themselves (for highlighting).
  bool _radiusPicked = false;
  bool _startPicked = false;
  bool _endPicked = false;
  bool _isCheckingArrival = false;
  Timer? _arrivalTimer;
  List<VacationWatch> _ownedWatches = [];

  final Map<String, bool> _selectedTasks = {
    'bins': true,
    'mail': true,
    'packages': true,
    'plants': false,
    'pets': false,
    'lights': false,
  };

  static final DateFormat _dayFormat = DateFormat('EEE, MMM d');
  static const _defaultHouseCenter = LatLng(0.3476, 32.5825);

  static const Map<
    String,
    ({String title, String schedule, String details, bool critical})
  >
  _taskCatalog = {
    'bins': (
      title: 'Trash bins',
      schedule: 'Set out and bring in on scheduled days',
      details: 'Keep the house looking occupied and tidy.',
      critical: false,
    ),
    'mail': (
      title: 'Mail sweep',
      schedule: 'Daily mailbox check',
      details: 'Stop mail buildup from signaling the owner is away.',
      critical: true,
    ),
    'packages': (
      title: 'Packages inside',
      schedule: 'Porch scan every shift',
      details: 'Bring parcels indoors to prevent porch theft.',
      critical: true,
    ),
    'plants': (
      title: 'Plant care',
      schedule: 'Water every 2 days',
      details: 'Spot-check outdoor and indoor plants.',
      critical: false,
    ),
    'pets': (
      title: 'Pet support',
      schedule: 'Feed and check bowls daily',
      details: 'Basic feed/refill support for pets staying home.',
      critical: true,
    ),
    'lights': (
      title: 'Light rotation',
      schedule: 'Switch lights on in the evening',
      details: 'Rotate a lamp or porch light to simulate activity.',
      critical: false,
    ),
  };

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now().add(const Duration(days: 1));
    _endDate = DateTime.now().add(const Duration(days: 4));
    _arrivalTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkArrivalTrigger();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkArrivalTrigger());
  }

  @override
  void dispose() {
    _addressChanged.dispose();
    for (final live in [
      _karmaPoints,
      _myTrips,
      _allTrips,
      ..._activity.values,
    ]) {
      live.close();
    }
    _arrivalTimer?.cancel();
    _addressController.dispose();
    _radiusController.dispose();
    _karmaController.dispose();
    super.dispose();
  }

  String get _currentUserId => widget.authService.currentUser?.uid ?? '';

  String get _currentUserName {
    final user = widget.authService.currentUser;
    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim();
    }
    if (user?.email?.trim().isNotEmpty == true) {
      return user!.email!.split('@').first;
    }
    return 'Member';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final firstDate = isStart ? DateTime.now() : (_startDate ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startPicked = true;
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = date.add(const Duration(days: 1));
        }
      } else {
        _endPicked = true;
        _endDate = date;
      }
    });
  }

  /// Saves [point] as the house position and fills the address box with
  /// the street address found there.
  Future<void> _pinHouse(LatLng point) async {
    _setAddressState(() {
      _houseLatitude = point.latitude;
      _houseLongitude = point.longitude;
      _isFindingAddress = true;
      _addressError = null;
    });
    final address = await _addressLookup.addressFor(point);
    if (!mounted) return;
    _setAddressState(() {
      _isFindingAddress = false;
      if (address != null) {
        _addressController.text = address;
      } else if (_addressController.text.trim().isEmpty) {
        _addressController.text =
            'Pinned location (${point.latitude.toStringAsFixed(5)}, '
            '${point.longitude.toStringAsFixed(5)})';
        _addressError =
            'Could not find the street name. You can type it in above.';
      }
    });
  }

  Future<void> _useCurrentLocationForHouse() async {
    _setAddressState(() {
      _isLocatingHouse = true;
      _addressError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Turn on location services first.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is needed to pin the house.');
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _setAddressState(() => _isLocatingHouse = false);
      await _pinHouse(LatLng(position.latitude, position.longitude));
    } catch (error) {
      if (!mounted) return;
      _setAddressState(() {
        _addressError = error is StateError
            ? error.message
            : 'Could not get your location. Try picking it on the map.';
      });
    } finally {
      if (mounted && _isLocatingHouse) {
        _setAddressState(() => _isLocatingHouse = false);
      }
    }
  }

  Future<LatLng> _resolveMapPickerCenter() async {
    if (_houseLatitude != null && _houseLongitude != null) {
      return LatLng(_houseLatitude!, _houseLongitude!);
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _defaultHouseCenter;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _defaultHouseCenter;
      }

      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return _defaultHouseCenter;
    }
  }

  Future<void> _pickHouseLocationOnMap() async {
    final initialCenter = await _resolveMapPickerCenter();
    if (!mounted) return;

    final selected = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => VacationHousePickerScreen(
          initialCenter: initialCenter,
          initialSelection: _houseLatitude == null || _houseLongitude == null
              ? null
              : LatLng(_houseLatitude!, _houseLongitude!),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    await _pinHouse(selected);
  }

  Future<void> _openDashboard() {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VacationWatchDashboardScreen(
          authService: widget.authService,
          repository: _repository,
        ),
      ),
    );
  }

  List<WatchTask> _buildTasks() {
    final tasks = <WatchTask>[];
    for (final entry in _selectedTasks.entries) {
      if (!entry.value) continue;
      final preset = _taskCatalog[entry.key]!;
      tasks.add(
        WatchTask(
          id: _uuid.v4(),
          title: preset.title,
          scheduleLabel: preset.schedule,
          details: preset.details,
          isCritical: preset.critical,
        ),
      );
    }
    return tasks;
  }

  List<WatchShift> _buildShifts(DateTime startDate, DateTime endDate) {
    final shifts = <WatchShift>[];
    var cursor = DateTime(startDate.year, startDate.month, startDate.day, 8);
    final lastDay = DateTime(endDate.year, endDate.month, endDate.day, 18);

    while (!cursor.isAfter(lastDay)) {
      shifts.add(
        WatchShift(
          id: _uuid.v4(),
          startsAt: cursor,
          endsAt: cursor.add(const Duration(hours: 10)),
          label: '${_dayFormat.format(cursor)} coverage',
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }

    return shifts;
  }

  Future<void> _createWatch() async {
    if (_currentUserId.isEmpty) {
      _showMessage('Sign in first before creating a vacation watch.');
      return;
    }

    final startDate = _startDate;
    final endDate = _endDate;
    final address = _addressController.text.trim();
    final radius = double.tryParse(_radiusController.text.trim());
    final karmaReward = int.tryParse(_karmaController.text.trim());

    if (startDate == null ||
        endDate == null ||
        address.isEmpty ||
        radius == null ||
        karmaReward == null) {
      _showMessage('Please complete the address, dates, radius, and karma.');
      return;
    }
    if (_houseLatitude == null || _houseLongitude == null) {
      _showMessage('Pick the house location on the map first.');
      return;
    }
    if (endDate.isBefore(startDate)) {
      _showMessage('Return date cannot be before the start date.');
      return;
    }

    final tasks = _buildTasks();
    if (tasks.isEmpty) {
      _showMessage('Pick at least one coverage task.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final watchId = await _repository.createWatch(
        VacationWatch(
          id: '',
          ownerId: _currentUserId,
          ownerName: _currentUserName,
          address: address,
          startDate: startDate,
          endDate: endDate,
          houseLatitude: _houseLatitude,
          houseLongitude: _houseLongitude,
          mode: _mode,
          tasks: tasks,
          shifts: _buildShifts(startDate, endDate),
          arrivalRadiusKm: radius,
          karmaReward: karmaReward,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      _showMessage(
        'Vacation watch created. Neighbors can start claiming days.',
      );
      setState(() {
        _showCreateForm = false;
        _addressController.clear();
        _houseLatitude = null;
        _houseLongitude = null;
        _mode = VacationWatchMode.neighborly;
        _startDate = DateTime.now().add(const Duration(days: 1));
        _endDate = DateTime.now().add(const Duration(days: 4));
        _radiusController.text = '8';
        _karmaController.text = '10';
        _radiusPicked = false;
        _startPicked = false;
        _endPicked = false;
        _planStep = 0;
        _selectedTasks.updateAll(
          (key, value) => key == 'bins' || key == 'mail' || key == 'packages',
        );
      });
      if (watchId.isNotEmpty && mounted) {
        await _openDashboard();
      }
    } catch (error) {
      _showMessage('Could not create vacation watch: $error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _checkArrivalTrigger({bool showSuccess = false}) async {
    if (_isCheckingArrival || _ownedWatches.isEmpty || _currentUserId.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final activeWatches = _ownedWatches.where((watch) {
      if (!watch.isActive || !watch.hasLocation) return false;
      final latestShiftEnd = (watch.shifts.isNotEmpty
          ? watch.shifts
                .map((shift) => shift.endsAt ?? shift.startsAt)
                .reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime(
              watch.endDate.year,
              watch.endDate.month,
              watch.endDate.day,
              18,
            ));
      return !now.isBefore(latestShiftEnd);
    }).toList();
    if (activeWatches.isEmpty) return;

    setState(() => _isCheckingArrival = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      var triggered = false;

      for (final watch in activeWatches) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          watch.houseLatitude!,
          watch.houseLongitude!,
        );
        if (distance <= watch.arrivalRadiusKm * 1000) {
          triggered = true;
          await _repository.markOwnerArrivingHome(
            watch: watch,
            actorId: _currentUserId,
            actorName: _currentUserName,
          );
        }
      }

      if (triggered && mounted && showSuccess) {
        _showMessage(
          'You are near home. Your vacation watch has been wrapped up.',
        );
      }
    } catch (_) {
      // Silent by default while the monitor is running.
    } finally {
      if (mounted) {
        setState(() => _isCheckingArrival = false);
      }
    }
  }

  Future<void> _claimShift(VacationWatch watch, WatchShift shift) async {
    try {
      await _repository.claimShift(
        watch: watch,
        shiftId: shift.id,
        watcherId: _currentUserId,
        watcherName: _currentUserName,
      );
      _showMessage('Shift claimed. You are on the roster now.');
    } catch (error) {
      _showMessage('Could not claim shift: $error');
    }
  }

  Future<void> _releaseShift(VacationWatch watch, WatchShift shift) async {
    try {
      await _repository.releaseShift(
        watch: watch,
        shiftId: shift.id,
        watcherId: _currentUserId,
        watcherName: _currentUserName,
      );
      _showMessage('Shift released back to the community board.');
    } catch (error) {
      _showMessage('Could not release shift: $error');
    }
  }

  Future<void> _openCheckIn(VacationWatch watch, WatchShift shift) async {
    final draft = await showModalBottomSheet<_ShiftActionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ShiftActionSheet(
        title: 'Daily check-in',
        submitLabel: 'Post check-in',
        tasks: watch.tasks,
        includeVibe: true,
      ),
    );
    if (draft == null) return;

    try {
      final photoUrls = draft.images.isEmpty
          ? const <String>[]
          : await _storageService.uploadImages(draft.images);
      await _repository.submitCheckIn(
        watch: watch,
        shiftId: shift.id,
        actorId: _currentUserId,
        actorName: _currentUserName,
        note: draft.note,
        vibe: draft.vibe ?? WatchVibe.routine,
        completedTaskIds: draft.completedTaskIds,
        photoUrls: photoUrls,
      );
      _showMessage('Check-in posted.');
    } catch (error) {
      _showMessage('Could not post check-in: $error');
    }
  }

  Future<void> _completeShift(VacationWatch watch, WatchShift shift) async {
    final draft = await showModalBottomSheet<_ShiftActionDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ShiftActionSheet(
        title: 'Finish shift',
        submitLabel: 'Complete shift',
        tasks: watch.tasks,
        includeVibe: false,
      ),
    );
    if (draft == null) return;

    try {
      final photoUrls = draft.images.isEmpty
          ? const <String>[]
          : await _storageService.uploadImages(draft.images);
      await _repository.completeShift(
        watch: watch,
        shiftId: shift.id,
        actorId: _currentUserId,
        actorName: _currentUserName,
        note: draft.note,
        photoUrls: photoUrls,
      );
      _showMessage('Shift completed. Karma added to your account.');
    } catch (error) {
      _showMessage('Could not complete shift: $error');
    }
  }

  Future<void> _raiseEmergency(VacationWatch watch) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency beacon'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Describe what you found: open gate, broken window, suspicious person...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Raise alert'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (note == null || note.isEmpty) return;

    try {
      await _repository.raiseEmergency(
        watch: watch,
        actorId: _currentUserId,
        actorName: _currentUserName,
        note: note,
      );
      _showMessage('Emergency beacon posted to the owner dashboard.');
    } catch (error) {
      _showMessage('Could not raise alert: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Step of the trip planner: 0 details, 1 tasks, 2 review.
  int _planStep = 0;
  final GlobalKey _planKey = GlobalKey();

  void _startPlanning() {
    setState(() {
      _showCreateForm = true;
      _planStep = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _planKey.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  /// Returns a message describing what is missing on [step], or null.
  String? _stepProblem(int step) {
    if (step == 0) {
      if (_addressController.text.trim().isEmpty) {
        return 'Add your home address.';
      }
      if (_houseLatitude == null || _houseLongitude == null) {
        return 'Pin your home on the map.';
      }
      if (_startDate == null || _endDate == null) return 'Pick your dates.';
      if (_endDate!.isBefore(_startDate!)) {
        return 'Return date cannot be before the start date.';
      }
    }
    if (step == 1) {
      if (!_selectedTasks.values.any((v) => v)) {
        return 'Pick at least one task.';
      }
      if (int.tryParse(_karmaController.text.trim()) == null) {
        return 'Set the karma reward.';
      }
    }
    return null;
  }

  void _nextStep() {
    final problem = _stepProblem(_planStep);
    if (problem != null) {
      _showMessage(problem);
      return;
    }
    setState(() => _planStep++);
  }

  Future<void> _editAddress() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => ListenableBuilder(
          listenable: _addressChanged,
          builder: (sheetContext, _) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Home address',
                  style: TextStyle(
                    color: HomeTone.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  autofocus: _addressController.text.isEmpty,
                  onChanged: (_) => setSheetState(() {}),
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: HomeTone.ink),
                  decoration: _plannerInput('e.g. Plot 4, Kira Road, Kampala'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineAction(
                        icon: Icons.map_outlined,
                        label: _houseLatitude == null
                            ? 'Pick on map'
                            : 'Repick on map',
                        onTap: _pickHouseLocationOnMap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _OutlineAction(
                        icon: Icons.my_location_rounded,
                        label: _isLocatingHouse
                            ? 'Locating…'
                            : 'Use my location',
                        onTap: _isLocatingHouse
                            ? null
                            : _useCurrentLocationForHouse,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _AddressStatus(
                  pinned: _houseLatitude != null,
                  busy: _isLocatingHouse || _isFindingAddress,
                  busyLabel: _isLocatingHouse
                      ? 'Getting your location…'
                      : 'Finding the address…',
                  error: _addressError,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: _plannerButton,
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Like setState, but also redraws the address sheet if it is open.
  void _setAddressState(VoidCallback change) {
    setState(change);
    _addressChanged.value++;
  }

  Future<void> _editRadius() async {
    var radius = double.tryParse(_radiusController.text.trim()) ?? 8;
    final picked = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      backgroundColor: HomeTone.card,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Arrival radius',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'When you come back within this distance of home, '
                'neighbours are told you are arriving.',
                style: TextStyle(color: HomeTone.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                '${radius.round()} km',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomeTone.violet,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Slider(
                value: radius,
                min: 1,
                max: 30,
                divisions: 29,
                activeColor: HomeTone.violet,
                label: '${radius.round()} km',
                onChanged: (v) => setSheetState(() => radius = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                style: _plannerButton,
                onPressed: () => Navigator.pop(sheetContext, radius),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _radiusController.text = picked.round().toString();
        _radiusPicked = true;
      });
    }
  }

  ButtonStyle get _plannerButton => FilledButton.styleFrom(
    backgroundColor: HomeTone.violet,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(46),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
  );

  InputDecoration _plannerInput(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: HomeTone.muted),
    filled: true,
    fillColor: HomeTone.canvas,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HomeTone.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HomeTone.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: HomeTone.violet, width: 1.5),
    ),
  );

  Widget _buildOwnerTab() {
    if (_currentUserId.isEmpty) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to plan a trip',
      );
    }

    return StreamBuilder<int>(
      stream: _karmaPoints.stream,
      initialData: _karmaPoints.latest,
      builder: (context, karmaSnapshot) {
        final karmaPoints = karmaSnapshot.data ?? 0;

        return StreamBuilder<List<VacationWatch>>(
          stream: _myTrips.stream,
          initialData: _myTrips.latest,
          builder: (context, snapshot) {
            final watches = snapshot.data ?? const <VacationWatch>[];
            final loading = !snapshot.hasData && !snapshot.hasError;
            final showForm = _showCreateForm || (!loading && watches.isEmpty);
            if (!identical(watches, _ownedWatches)) {
              _ownedWatches = watches;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkArrivalTrigger();
              });
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                const _AwayHeroCard(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      color: HomeTone.ink,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'My Trips',
                        style: TextStyle(
                          color: HomeTone.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _KarmaEarnedPill(points: karmaPoints),
                  ],
                ),
                const SizedBox(height: 10),
                if (snapshot.hasError)
                  const _NoTripsCard(
                    title: 'Could not load your trips',
                    message: 'Check your connection and try again.',
                  )
                else if (loading)
                  const SkeletonBox(
                    height: 140,
                    radius: 20,
                    color: HomeTone.skeleton,
                  )
                else if (watches.isEmpty)
                  _NoTripsCard(
                    title: 'No trips planned yet',
                    message:
                        'Plan a trip and invite trusted neighbours to keep an '
                        'eye on your home.',
                    onPlan: _startPlanning,
                  )
                else ...[
                  for (final (i, watch) in watches.indexed)
                    _OwnerWatchCard(
                      key: ValueKey(watch.id),
                      watch: watch,
                      // The first (most relevant) trip starts open.
                      initiallyExpanded: i == 0,
                      onOpenDashboard: _openDashboard,
                      onCancel:
                          watch.status == VacationWatchStatus.completed ||
                              watch.status == VacationWatchStatus.cancelled
                          ? null
                          : () => _repository.cancelWatch(watch.id),
                      activityStream: _activityFor(watch.id),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _OutlineAction(
                        icon: Icons.dashboard_outlined,
                        label: 'Trip dashboard',
                        onTap: _openDashboard,
                      ),
                      _OutlineAction(
                        icon: Icons.radar_outlined,
                        label: _isCheckingArrival
                            ? 'Checking…'
                            : 'Check if I’m home',
                        onTap: () => _checkArrivalTrigger(showSuccess: true),
                      ),
                      if (!showForm)
                        _OutlineAction(
                          icon: Icons.add_rounded,
                          label: 'Plan a new trip',
                          onTap: _startPlanning,
                        ),
                    ],
                  ),
                ],
                if (showForm) ...[
                  const SizedBox(height: 18),
                  KeyedSubtree(key: _planKey, child: _buildPlanner()),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlanner() {
    final steps = ['Details', 'Tasks', 'Review'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: HomeTone.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HomeTone.border),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: HomeTone.violetDim,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: HomeTone.violet,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Plan a Trip',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _StepChip(
                    number: i + 1,
                    label: steps[i],
                    state: i == _planStep
                        ? _StepState.current
                        : i < _planStep
                        ? _StepState.done
                        : _StepState.todo,
                    // Going back is always allowed; going forward checks.
                    onTap: i < _planStep
                        ? () => setState(() => _planStep = i)
                        : null,
                  ),
                ),
              ],
            ],
          ),
          const Divider(height: 24, color: HomeTone.border),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(
              key: ValueKey(_planStep),
              child: switch (_planStep) {
                0 => _buildDetailsStep(),
                1 => _buildTasksStep(),
                _ => _buildReviewStep(),
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_planStep > 0) ...[
                SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HomeTone.violet,
                      minimumSize: const Size(0, 46),
                      side: const BorderSide(color: HomeTone.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => setState(() => _planStep--),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton(
                  style: _plannerButton,
                  onPressed: _isSubmitting
                      ? null
                      : _planStep < 2
                      ? _nextStep
                      : _createWatch,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _planStep == 0
                            ? 'Continue to Tasks'
                            : _planStep == 1
                            ? 'Continue to Review'
                            : _isSubmitting
                            ? 'Saving…'
                            : 'Ask neighbours for help',
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _planStep < 2
                            ? Icons.chevron_right_rounded
                            : Icons.check_rounded,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final address = _addressController.text.trim();
    final radius = _radiusController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PlannerLabel('Who will look after your home?'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ModeOption(
                icon: Icons.groups_outlined,
                label: 'Neighbours',
                selected: _mode == VacationWatchMode.neighborly,
                onTap: () =>
                    setState(() => _mode = VacationWatchMode.neighborly),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeOption(
                icon: Icons.work_outline_rounded,
                label: 'Paid Carer',
                selected: _mode == VacationWatchMode.proCare,
                onTap: () => setState(() => _mode = VacationWatchMode.proCare),
              ),
            ),
          ],
        ),
        if (_mode == VacationWatchMode.proCare)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HomeTone.violetDim,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Paid carers are arranged by hand for now. You agree the fee '
              'with the carer directly.',
              style: TextStyle(color: HomeTone.ink, fontSize: 12.5),
            ),
          ),
        const SizedBox(height: 12),
        _TwoColumn(
          children: [
            _FieldTile(
              icon: Icons.location_on_outlined,
              label: 'Home Address',
              value: address.isEmpty
                  ? 'Tap to add'
                  : _houseLatitude == null
                  ? '$address · not pinned'
                  : address,
              muted: address.isEmpty,
              selected: address.isNotEmpty && _houseLatitude != null,
              onTap: _editAddress,
            ),
            _FieldTile(
              icon: Icons.gps_fixed_rounded,
              label: 'Arrival Radius',
              value: radius.isEmpty ? 'Tap to set' : '$radius km',
              selected: _radiusPicked,
              onTap: _editRadius,
            ),
            _FieldTile(
              icon: Icons.calendar_today_outlined,
              label: 'Start Date',
              value: _startDate == null
                  ? 'Select'
                  : _dayFormat.format(_startDate!),
              selected: _startPicked,
              onTap: () => _pickDate(isStart: true),
            ),
            _FieldTile(
              icon: Icons.event_outlined,
              label: 'Return Date',
              value: _endDate == null ? 'Select' : _dayFormat.format(_endDate!),
              selected: _endPicked,
              onTap: () => _pickDate(isStart: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTasksStep() {
    final karma = int.tryParse(_karmaController.text.trim()) ?? 10;
    const icons = {
      'bins': Icons.delete_outline_rounded,
      'mail': Icons.mail_outline_rounded,
      'packages': Icons.inventory_2_outlined,
      'plants': Icons.local_florist_outlined,
      'pets': Icons.pets_rounded,
      'lights': Icons.lightbulb_outline_rounded,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PlannerLabel('What should neighbours do?'),
        const SizedBox(height: 8),
        _TwoColumn(
          children: [
            for (final entry in _taskCatalog.entries)
              _TaskToggle(
                icon: icons[entry.key] ?? Icons.check_circle_outline,
                title: entry.value.title,
                subtitle: entry.value.schedule,
                value: _selectedTasks[entry.key] ?? false,
                onChanged: (v) => setState(() => _selectedTasks[entry.key] = v),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _PlannerLabel('Karma reward per day'),
        const SizedBox(height: 4),
        const Text(
          'Thank-you points a neighbour earns for each day they cover.',
          style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in const [5, 10, 15, 20, 30])
              ChoiceChip(
                label: Text('$value'),
                avatar: const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Color(0xFFE6A700),
                ),
                selected: karma == value,
                showCheckmark: false,
                selectedColor: HomeTone.violetDim,
                backgroundColor: HomeTone.card,
                side: BorderSide(
                  color: karma == value ? HomeTone.violet : HomeTone.border,
                ),
                labelStyle: TextStyle(
                  color: karma == value ? HomeTone.violet : HomeTone.ink,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) =>
                    setState(() => _karmaController.text = '$value'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final tasks = [
      for (final entry in _taskCatalog.entries)
        if (_selectedTasks[entry.key] ?? false) entry.value.title,
    ];
    final start = _startDate;
    final end = _endDate;
    final days = start == null || end == null
        ? 0
        : end.difference(start).inDays + 1;
    final karma = int.tryParse(_karmaController.text.trim()) ?? 0;
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: HomeTone.violet),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: HomeTone.muted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: HomeTone.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PlannerLabel('Check your trip'),
        const SizedBox(height: 10),
        row(
          Icons.groups_outlined,
          'Looked after by',
          _mode == VacationWatchMode.neighborly ? 'Neighbours' : 'Paid carer',
        ),
        row(Icons.location_on_outlined, 'Home', _addressController.text.trim()),
        row(
          Icons.calendar_today_outlined,
          'Dates',
          start == null || end == null
              ? '-'
              : '${_dayFormat.format(start)} – ${_dayFormat.format(end)} '
                    '($days day${days == 1 ? '' : 's'})',
        ),
        row(
          Icons.gps_fixed_rounded,
          'Arrival radius',
          '${_radiusController.text.trim()} km',
        ),
        row(Icons.checklist_rounded, 'Tasks', tasks.join(', ')),
        row(
          Icons.star_outline_rounded,
          'Karma',
          '$karma per day · up to ${karma * days} in total',
        ),
      ],
    );
  }

  Widget _buildCoverageTab() {
    if (_currentUserId.isEmpty) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to help neighbours',
      );
    }

    return StreamBuilder<List<VacationWatch>>(
      stream: _allTrips.stream,
      initialData: _allTrips.latest,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load open days',
            message: 'Check your connection and try again.',
          );
        }

        final watches = snapshot.data ?? const <VacationWatch>[];
        final activeWatches = watches
            .where(
              (watch) =>
                  watch.status != VacationWatchStatus.completed &&
                  watch.status != VacationWatchStatus.cancelled,
            )
            .toList();

        final myAssigned = <({VacationWatch watch, WatchShift shift})>[];
        final watchBoard = <VacationWatch>[];

        for (final watch in activeWatches) {
          var hasOpenShift = false;
          for (final shift in watch.shifts) {
            if (shift.isAssignedTo(_currentUserId) &&
                shift.status != WatchShiftStatus.completed) {
              myAssigned.add((watch: watch, shift: shift));
            } else if (shift.isOpen && watch.ownerId != _currentUserId) {
              hasOpenShift = true;
            }
          }
          if (hasOpenShift && watch.ownerId != _currentUserId) {
            watchBoard.add(watch);
          }
        }

        myAssigned.sort((a, b) => a.shift.startsAt.compareTo(b.shift.startsAt));
        watchBoard.sort((a, b) => a.startDate.compareTo(b.startDate));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            const _SupportHeroCard(),
            const SizedBox(height: 14),
            _HelpSection(
              icon: Icons.event_available_outlined,
              title: 'Days you are covering',
              subtitle:
                  'Check in when you visit, hand off to the next neighbour, '
                  'or raise an alert.',
              child: myAssigned.isEmpty
                  ? _NothingYetBox(onViewOpenDays: _scrollToOpenDays)
                  : Column(
                      children: [
                        for (final item in myAssigned)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CoverageCard(
                              watch: item.watch,
                              shift: item.shift,
                              onCheckIn: () =>
                                  _openCheckIn(item.watch, item.shift),
                              onComplete: () =>
                                  _completeShift(item.watch, item.shift),
                              onEmergency: () => _raiseEmergency(item.watch),
                              onRelease: () =>
                                  _releaseShift(item.watch, item.shift),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _HelpSection(
              key: _openDaysKey,
              icon: Icons.diversity_3_outlined,
              title: 'Neighbours who need help',
              subtitle: 'Tap a day to sign up for it.',
              child: watchBoard.isEmpty
                  ? const _NoOneAwayBox()
                  : Column(
                      children: [
                        for (final watch in watchBoard)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _VacationBoardCard(
                              watch: watch,
                              onClaimShift: (shift) =>
                                  _claimShift(watch, shift),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  final GlobalKey _openDaysKey = GlobalKey();

  void _scrollToOpenDays() {
    final target = _openDaysKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: HomeTone.canvas,
          body: Column(
            children: [
              const PageHeroHeader(
                title: 'Vacation Watch',
                subtitle: 'Keep your home safe while you’re away',
                badge: _ShieldHouseBadge(),
                bottom: _PillTabs(),
              ),
              Expanded(
                child: TabBarView(
                  children: [_buildOwnerTab(), _buildCoverageTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerWatchCard extends StatefulWidget {
  const _OwnerWatchCard({
    super.key,
    required this.watch,
    required this.activityStream,
    required this.onOpenDashboard,
    this.onCancel,
    this.initiallyExpanded = false,
  });

  final VacationWatch watch;
  final Stream<List<WatchActivity>> activityStream;
  final VoidCallback onOpenDashboard;
  final Future<void> Function()? onCancel;
  final bool initiallyExpanded;

  @override
  State<_OwnerWatchCard> createState() => _OwnerWatchCardState();
}

class _OwnerWatchCardState extends State<_OwnerWatchCard> {
  late bool _expanded = widget.initiallyExpanded;

  VacationWatch get watch => widget.watch;

  Future<void> _confirmCancel() async {
    final cancel = widget.onCancel;
    if (cancel == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HomeTone.card,
        title: const Text(
          'Cancel this watch?',
          style: TextStyle(color: HomeTone.ink, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Neighbours will no longer be able to claim days for this trip.',
          style: TextStyle(color: HomeTone.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HomeTone.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel watch'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cancel();
  }

  void _showActivity(List<WatchActivity> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: HomeTone.card,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Activity',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (items.isEmpty)
              const Text(
                'No updates logged yet.',
                style: TextStyle(color: HomeTone.muted),
              ),
            for (final item in items) ...[
              ActivityTile(item: item),
              if (item.photoUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 14, bottom: 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final url in item.photoUrls)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            url,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 70,
                              height: 70,
                              color: HomeTone.violetDim,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: HomeTone.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, tint) = tripStatus(watch);
    final shifts = [...watch.shifts]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HomeTone.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomeTone.border),
        boxShadow: HomeTone.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: always visible; tapping it opens or closes the card.
          Semantics(
            button: true,
            expanded: _expanded,
            onTapHint: _expanded ? 'Hide trip details' : 'Show trip details',
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: HomeTone.violetDim,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.home_outlined,
                        color: HomeTone.violet,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            watch.address.trim().isEmpty
                                ? 'My home'
                                : watch.address.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomeTone.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: HomeTone.muted,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  tripDateRange(watch),
                                  style: const TextStyle(
                                    color: HomeTone.ink,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
                      decoration: BoxDecoration(
                        color: tint,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: PopupMenuButton<String>(
                        tooltip: 'Trip options',
                        padding: EdgeInsets.zero,
                        color: HomeTone.card,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: HomeTone.ink,
                          size: 20,
                        ),
                        onSelected: (value) {
                          if (value == 'dashboard') widget.onOpenDashboard();
                          if (value == 'cancel') _confirmCancel();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'dashboard',
                            child: Text(
                              'Trip dashboard',
                              style: TextStyle(color: HomeTone.ink),
                            ),
                          ),
                          if (widget.onCancel != null)
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Text(
                                'Cancel watch',
                                style: TextStyle(color: HomeTone.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: HomeTone.violet,
                        size: 26,
                        semanticLabel: 'Expand',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Closed: one line of numbers. Open: the full breakdown.
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded ? _details(shifts) : _summaryLine(),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine() => Padding(
    padding: const EdgeInsets.fromLTRB(66, 0, 12, 12),
    child: Text(
      '${watch.openShiftCount} open  ·  ${watch.claimedShiftCount} claimed  ·  '
      '${watch.completedShiftCount} completed  ·  ${watch.karmaReward} karma/shift',
      style: const TextStyle(color: HomeTone.muted, fontSize: 12),
    ),
  );

  Widget _details(List<WatchShift> shifts) {
    const divider = Divider(height: 22, color: HomeTone.border);
    const heading = TextStyle(
      color: HomeTone.ink,
      fontSize: 15,
      fontWeight: FontWeight.w800,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TripMetric(
                  icon: Icons.visibility_outlined,
                  value: watch.openShiftCount,
                  label: 'Open shifts',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TripMetric(
                  icon: Icons.flag_outlined,
                  value: watch.claimedShiftCount,
                  label: 'Claimed',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TripMetric(
                  icon: Icons.check_circle_outline_rounded,
                  value: watch.completedShiftCount,
                  label: 'Completed',
                  color: HomeTone.green,
                  tint: HomeTone.greenDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EFFC),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: Color(0xFFE6A700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${watch.karmaReward} karma / shift',
                  style: const TextStyle(color: HomeTone.ink, fontSize: 13),
                ),
              ],
            ),
          ),
          divider,
          Row(
            children: [
              const Expanded(child: Text('Tasks', style: heading)),
              if (watch.tasks.isNotEmpty)
                TextButton(
                  onPressed: () => showTaskDetailsSheet(context, watch),
                  style: TextButton.styleFrom(
                    foregroundColor: HomeTone.violet,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Task details',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (watch.tasks.isEmpty)
            const Text(
              'No tasks were set for this trip.',
              style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final task in watch.tasks) TaskChip(task: task)],
            ),
          divider,
          const Text('Roster Timeline', style: heading),
          const SizedBox(height: 6),
          if (shifts.isEmpty)
            const Text(
              'No days to cover.',
              style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
            )
          else
            RosterTimeline(shifts: shifts),
          divider,
          Row(
            children: [
              Expanded(
                child: StreamBuilder<List<WatchActivity>>(
                  stream: widget.activityStream,
                  builder: (context, snapshot) {
                    final items = [...?snapshot.data]
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showActivity(items),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: HomeTone.violet,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Activity', style: heading),
                                  Text(
                                    items.isEmpty
                                        ? 'No updates yet'
                                        : '${items.length} update'
                                              '${items.length == 1 ? '' : 's'} logged',
                                    style: const TextStyle(
                                      color: HomeTone.muted,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: HomeTone.muted,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _confirmCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomeTone.violet,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: HomeTone.violet, width: 1.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel Watch'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ShiftActionDraft {
  const _ShiftActionDraft({
    required this.note,
    required this.completedTaskIds,
    required this.images,
    this.vibe,
  });

  final String note;
  final List<String> completedTaskIds;
  final List<XFile> images;
  final WatchVibe? vibe;
}

class _ShiftActionSheet extends StatefulWidget {
  const _ShiftActionSheet({
    required this.title,
    required this.submitLabel,
    required this.tasks,
    required this.includeVibe,
  });

  final String title;
  final String submitLabel;
  final List<WatchTask> tasks;
  final bool includeVibe;

  @override
  State<_ShiftActionSheet> createState() => _ShiftActionSheetState();
}

class _ShiftActionSheetState extends State<_ShiftActionSheet> {
  final TextEditingController _noteController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final Set<String> _completedTaskIds = {};
  final List<XFile> _images = [];
  WatchVibe _vibe = WatchVibe.routine;

  @override
  void initState() {
    super.initState();
    _completedTaskIds.addAll(widget.tasks.map((task) => task.id));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    setState(() => _images.add(image));
  }

  void _submit() {
    final note = _noteController.text.trim();
    if (note.isEmpty) return;
    Navigator.pop(
      context,
      _ShiftActionDraft(
        note: note,
        completedTaskIds: _completedTaskIds.toList(),
        images: _images,
        vibe: widget.includeVibe ? _vibe : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (widget.includeVibe) ...[
              Text(
                'How did it feel?',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WatchVibe.values.map((vibe) {
                  return ChoiceChip(
                    label: Text(vibe.label),
                    selected: _vibe == vibe,
                    onSelected: (_) => setState(() => _vibe = vibe),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              'Tasks completed',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...widget.tasks.map(
              (task) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _completedTaskIds.contains(task.id),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _completedTaskIds.add(task.id);
                    } else {
                      _completedTaskIds.remove(task.id);
                    }
                  });
                },
                title: Text(task.title),
                subtitle: Text(task.scheduleLabel),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Front door locked, mail inside, all quiet...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Add photo'),
                ),
                const SizedBox(width: 10),
                if (_images.isNotEmpty)
                  Text('${_images.length} photo(s) attached'),
              ],
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            _images[index].path,
                            width: 74,
                            height: 74,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, _) => Container(
                              width: 74,
                              height: 74,
                              color: AppColors.border,
                              child: const Icon(Icons.image_outlined),
                            ),
                          )
                        : Image.file(
                            File(_images[index].path),
                            width: 74,
                            height: 74,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, _) => Container(
                              width: 74,
                              height: 74,
                              color: AppColors.border,
                              child: const Icon(Icons.image_outlined),
                            ),
                          ),
                  ),
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemCount: _images.length,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ new My Trips UI

/// Two pill-shaped tabs: the selected one is filled violet.
class _PillTabs extends StatelessWidget {
  const _PillTabs();

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    const tabs = [
      (Icons.luggage_outlined, 'My Trips'),
      (Icons.groups_outlined, 'Help Neighbours'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EDFA),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Semantics(
                    selected: controller.index == i,
                    button: true,
                    child: GestureDetector(
                      onTap: () => controller.animateTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 40,
                        decoration: BoxDecoration(
                          color: controller.index == i
                              ? HomeTone.violet
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              tabs[i].$1,
                              size: 19,
                              color: controller.index == i
                                  ? Colors.white
                                  : HomeTone.ink,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tabs[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: controller.index == i
                                      ? Colors.white
                                      : HomeTone.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShieldHouseBadge extends StatelessWidget {
  const _ShieldHouseBadge();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.verified_user_rounded,
        color: Colors.white,
        size: 30,
      ),
    ),
  );
}

class _AwayHeroCard extends StatelessWidget {
  const _AwayHeroCard();

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.visibility_outlined, 'Home check'),
      (Icons.inventory_2_outlined, 'Collect packages'),
      (Icons.delete_outline_rounded, 'Manage tasks'),
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6F2FF), Color(0xFFE3D8FF)],
        ),
        boxShadow: HomeTone.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8,
            bottom: -10,
            child: ExcludeSemantics(
              child: Icon(
                Icons.home_rounded,
                size: 92,
                color: HomeTone.violet.withValues(alpha: .35),
              ),
            ),
          ),
          Positioned(
            right: 70,
            top: 14,
            child: ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: HomeTone.cardShadow,
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: HomeTone.violet,
                  size: 20,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Away from home?',
                        style: TextStyle(
                          color: HomeTone.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Let your neighbours look out for you.',
                        style: TextStyle(color: HomeTone.ink, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (icon, label) in features)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .85),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 15, color: HomeTone.violet),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: const TextStyle(
                                color: HomeTone.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KarmaEarnedPill extends StatelessWidget {
  const _KarmaEarnedPill({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: HomeTone.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 18, color: Color(0xFFE6A700)),
        const SizedBox(width: 4),
        Text(
          '$points karma earned',
          style: const TextStyle(
            color: HomeTone.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _NoTripsCard extends StatelessWidget {
  const _NoTripsCard({required this.title, required this.message, this.onPlan});
  final String title;
  final String message;
  final VoidCallback? onPlan;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
    ),
    child: Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: HomeTone.violetDim,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.event_note_rounded,
            color: HomeTone.violet,
            size: 34,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: const TextStyle(color: HomeTone.muted, fontSize: 12.5),
              ),
              if (onPlan != null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onPlan,
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeTone.violet,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Plan a Trip'),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

enum _StepState { todo, current, done }

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.number,
    required this.label,
    required this.state,
    this.onTap,
  });
  final int number;
  final String label;
  final _StepState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state != _StepState.todo;
    return Semantics(
      label:
          'Step $number, $label'
          '${state == _StepState.current ? ', current' : ''}',
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          decoration: BoxDecoration(
            color: state == _StepState.current
                ? HomeTone.violetDim
                : const Color(0xFFF4F2F8),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? HomeTone.violet : const Color(0xFFCFCADB),
                  shape: BoxShape.circle,
                ),
                child: state == _StepState.done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? HomeTone.violet : HomeTone.muted,
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlannerLabel extends StatelessWidget {
  const _PlannerLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: HomeTone.ink,
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
    ),
  );
}

/// Lays children out two per row, each row as tall as its tallest child.
class _TwoColumn extends StatelessWidget {
  const _TwoColumn({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: 8),
              Expanded(
                child: i + 1 < children.length
                    ? children[i + 1]
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected ? HomeTone.violetDim : HomeTone.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? HomeTone.violet : HomeTone.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: selected ? HomeTone.violet : HomeTone.ink,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? HomeTone.violet : HomeTone.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: -7,
            right: -5,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: HomeTone.violet,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;

  /// Set by the user: tinted, outlined in violet and ticked.
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label, $value${selected ? ', set' : ''}',
    excludeSemantics: true,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? HomeTone.violetDim : HomeTone.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? HomeTone.violet : HomeTone.border,
                width: selected ? 1.6 : 1,
              ),
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: HomeTone.violet),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: selected ? HomeTone.violet : HomeTone.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: muted ? HomeTone.muted : HomeTone.ink,
                            fontSize: muted ? 12 : 13.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: HomeTone.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selected)
          Positioned(
            top: -6,
            right: -5,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: HomeTone.violet,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),
  );
}

/// Under the address box: spinner while working, error, or pinned status.
class _AddressStatus extends StatelessWidget {
  const _AddressStatus({
    required this.pinned,
    required this.busy,
    required this.busyLabel,
    this.error,
  });
  final bool pinned;
  final bool busy;
  final String busyLabel;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (Widget icon, String text, Color color) = busy
        ? (
            const SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: HomeTone.violet,
              ),
            ),
            busyLabel,
            HomeTone.muted,
          )
        : error != null
        ? (
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: HomeTone.red,
            ),
            error!,
            HomeTone.red,
          )
        : pinned
        ? (
            const Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: HomeTone.green,
            ),
            'Pinned on the map',
            HomeTone.green,
          )
        : (
            const Icon(
              Icons.location_off_outlined,
              size: 16,
              color: HomeTone.muted,
            ),
            'Not pinned on the map yet',
            HomeTone.muted,
          );
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _TaskToggle extends StatelessWidget {
  const _TaskToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: '$title, $subtitle',
    excludeSemantics: true,
    child: Material(
      color: HomeTone.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: value ? HomeTone.violet : HomeTone.border),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: HomeTone.ink),
                  const Spacer(),
                  SizedBox(
                    height: 28,
                    child: FittedBox(
                      child: Switch(
                        value: value,
                        onChanged: onChanged,
                        activeThumbColor: Colors.white,
                        activeTrackColor: HomeTone.violet,
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: HomeTone.border,
                        trackOutlineColor: const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: HomeTone.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: HomeTone.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: HomeTone.violet,
      backgroundColor: HomeTone.card,
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: const BorderSide(color: HomeTone.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

// --------------------------------------------------------- Help Neighbours UI

class _SupportHeroCard extends StatelessWidget {
  const _SupportHeroCard();

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF6F2FF), Color(0xFFE3D8FF)],
      ),
      boxShadow: HomeTone.cardShadow,
    ),
    child: Stack(
      children: [
        Positioned(
          right: 8,
          bottom: -10,
          child: ExcludeSemantics(
            child: Icon(
              Icons.home_rounded,
              size: 92,
              color: HomeTone.violet.withValues(alpha: .35),
            ),
          ),
        ),
        Positioned(
          right: 66,
          top: 12,
          child: ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: HomeTone.cardShadow,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: HomeTone.violet,
                size: 21,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 112, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Support neighbours while they’re away',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Check in on homes, complete simple tasks, and help keep the '
                'neighbourhood safe.',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// White panel with an icon, title and subtitle. The › arrow (or tapping
/// the header) folds the content away and back.
class _HelpSection extends StatefulWidget {
  const _HelpSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  State<_HelpSection> createState() => _HelpSectionState();
}

class _HelpSectionState extends State<_HelpSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: HomeTone.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: HomeTone.border),
      boxShadow: HomeTone.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: HomeTone.violetDim,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: HomeTone.violet, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: HomeTone.ink,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            color: HomeTone.muted,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? .25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: HomeTone.ink,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: widget.child,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    ),
  );
}

/// Dashed empty box for "Days you are covering".
class _NothingYetBox extends StatelessWidget {
  const _NothingYetBox({required this.onViewOpenDays});
  final VoidCallback onViewOpenDays;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _DashedOutline(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: HomeTone.violet,
            size: 40,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nothing yet',
            style: TextStyle(
              color: HomeTone.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Pick an open day below and it will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onViewOpenDays,
            style: FilledButton.styleFrom(
              backgroundColor: HomeTone.violet,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.event_available_outlined, size: 19),
            label: const Text('View Open Days'),
          ),
        ],
      ),
    ),
  );
}

class _DashedOutline extends CustomPainter {
  const _DashedOutline();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HomeTone.violet.withValues(alpha: .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.6),
          const Radius.circular(16),
        ),
      );
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, d + 4.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Lavender empty box for "Neighbours who need help".
class _NoOneAwayBox extends StatelessWidget {
  const _NoOneAwayBox();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3EFFC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: HomeTone.cardShadow,
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: HomeTone.violet,
              size: 34,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No one is away right now',
                style: TextStyle(
                  color: HomeTone.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'When a neighbour plans a trip, their open days will '
                'appear here.',
                style: TextStyle(color: HomeTone.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// A day the user has signed up to cover, with its actions.
class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.watch,
    required this.shift,
    required this.onCheckIn,
    required this.onComplete,
    required this.onEmergency,
    required this.onRelease,
  });

  final VacationWatch watch;
  final WatchShift shift;
  final VoidCallback onCheckIn;
  final VoidCallback onComplete;
  final VoidCallback onEmergency;
  final VoidCallback onRelease;

  ButtonStyle _style(Color bg, Color fg, {Color? border}) =>
      OutlinedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        side: BorderSide(color: border ?? bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      );

  @override
  Widget build(BuildContext context) {
    final owner = watch.ownerName.trim().split(RegExp(r'\s+')).first;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: HomeTone.violetDim,
                child: Text(
                  owner.isEmpty ? '?' : owner[0].toUpperCase(),
                  style: const TextStyle(
                    color: HomeTone.violet,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.isEmpty ? watch.address : '$owner’s home',
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${DateFormat('EEE, MMM d').format(shift.startsAt)}'
                      '  ·  ${watch.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (watch.tasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final task in watch.tasks) TaskChip(task: task)],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCheckIn,
                  style: _style(
                    HomeTone.card,
                    HomeTone.violet,
                    border: HomeTone.violet,
                  ),
                  child: const Text('Check in'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onComplete,
                  style: _style(HomeTone.violet, Colors.white),
                  child: const Text('Complete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRelease,
                  style: _style(
                    HomeTone.card,
                    HomeTone.ink,
                    border: HomeTone.border,
                  ),
                  child: const Text('Release shift'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEmergency,
                  style: _style(HomeTone.red, Colors.white),
                  icon: const Icon(Icons.warning_rounded, size: 17),
                  label: const Text('Emergency'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A neighbour who is away, with their open days to claim.
class _VacationBoardCard extends StatelessWidget {
  const _VacationBoardCard({required this.watch, required this.onClaimShift});

  final VacationWatch watch;
  final void Function(WatchShift shift) onClaimShift;

  @override
  Widget build(BuildContext context) {
    final openShifts = watch.shifts.where((shift) => shift.isOpen).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final owner = watch.ownerName.trim().split(RegExp(r'\s+')).first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: HomeTone.violetDim,
                child: Text(
                  owner.isEmpty ? '?' : owner[0].toUpperCase(),
                  style: const TextStyle(
                    color: HomeTone.violet,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.isEmpty ? 'Neighbour' : '$owner’s home',
                      style: const TextStyle(
                        color: HomeTone.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${tripDateRange(watch)}  ·  ${watch.address}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomeTone.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E0),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFFE6A700),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${watch.karmaReward}/day',
                      style: const TextStyle(
                        color: Color(0xFFB7791F),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (watch.tasks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final task in watch.tasks) TaskChip(task: task)],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Open days · tap one to sign up',
            style: TextStyle(
              color: HomeTone.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final shift in openShifts)
                Semantics(
                  button: true,
                  label:
                      'Sign up for ${DateFormat('EEEE, MMMM d').format(shift.startsAt)}',
                  excludeSemantics: true,
                  child: Material(
                    color: HomeTone.card,
                    shape: const StadiumBorder(
                      side: BorderSide(color: HomeTone.violet),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onClaimShift(shift),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 16,
                              color: HomeTone.violet,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('EEE, MMM d').format(shift.startsAt),
                              style: const TextStyle(
                                color: HomeTone.violet,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
