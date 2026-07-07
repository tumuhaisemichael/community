import 'dart:async';
import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/vacation_watch.dart';
import '../repositories/vacation_watch_repository.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'vacation_house_picker_screen.dart';
import 'vacation_watch_dashboard_screen.dart';

class VacationWatchScreen extends StatefulWidget {
  const VacationWatchScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<VacationWatchScreen> createState() => _VacationWatchScreenState();
}

class _VacationWatchScreenState extends State<VacationWatchScreen> {
  final VacationWatchRepository _repository = VacationWatchRepository();
  final StorageService _storageService = StorageService();
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
  bool _isLocatingHouse = false;
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
        _startDate = date;
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = date.add(const Duration(days: 1));
        }
      } else {
        _endDate = date;
      }
    });
  }

  Future<void> _useCurrentLocationForHouse() async {
    setState(() => _isLocatingHouse = true);
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
      setState(() {
        _houseLatitude = position.latitude;
        _houseLongitude = position.longitude;
      });
      _showMessage('House location saved from your current position.');
    } catch (error) {
      _showMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _isLocatingHouse = false);
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
    setState(() {
      _houseLatitude = selected.latitude;
      _houseLongitude = selected.longitude;
    });
    _showMessage('House location pinned on the map.');
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
        _addressController.clear();
        _houseLatitude = null;
        _houseLongitude = null;
        _mode = VacationWatchMode.neighborly;
        _startDate = DateTime.now().add(const Duration(days: 1));
        _endDate = DateTime.now().add(const Duration(days: 4));
        _radiusController.text = '8';
        _karmaController.text = '10';
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

  Widget _buildOwnerTab() {
    if (_currentUserId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Sign in to create and manage vacation watches.'),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .snapshots(),
      builder: (context, karmaSnapshot) {
        final karmaPoints =
            (karmaSnapshot.data?.data()?['karmaPoints'] as num?)?.toInt() ?? 0;

        return StreamBuilder<List<VacationWatch>>(
          stream: _repository.watchOwnedBy(_currentUserId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load your watch dashboard: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final watches = snapshot.data ?? const <VacationWatch>[];
            _ownedWatches = watches;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkArrivalTrigger();
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              children: [
                _HeroBanner(
                  karmaPoints: karmaPoints,
                  isCheckingArrival: _isCheckingArrival,
                ),
                const SizedBox(height: 18),
                _SectionCard(
                  title: 'Create a watch plan',
                  subtitle:
                      'Define the house, tasks, and coverage calendar before you leave.',
                  child: Column(
                    children: [
                      SegmentedButton<VacationWatchMode>(
                        segments: const [
                          ButtonSegment(
                            value: VacationWatchMode.neighborly,
                            label: Text('Neighborly Help'),
                            icon: Icon(Icons.handshake_outlined),
                          ),
                          ButtonSegment(
                            value: VacationWatchMode.proCare,
                            label: Text('Pro Care'),
                            icon: Icon(Icons.work_outline),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (selection) {
                          setState(() => _mode = selection.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_mode == VacationWatchMode.proCare)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.watchDim,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Pro Care works as a manually arranged paid watch for now. Marketplace matching and escrow can come later.',
                          ),
                        ),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'House address',
                          hintText: 'Enter the property address',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickHouseLocationOnMap,
                              icon: const Icon(Icons.map_outlined),
                              label: Text(
                                _houseLatitude == null
                                    ? 'Pick on map'
                                    : 'Repick on map',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _radiusController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Arrival radius (km)',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_houseLatitude != null &&
                          _houseLongitude != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.watchDim,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Pinned house: ${_houseLatitude!.toStringAsFixed(5)}, ${_houseLongitude!.toStringAsFixed(5)}',
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _isLocatingHouse
                              ? null
                              : _useCurrentLocationForHouse,
                          icon: const Icon(Icons.my_location_outlined),
                          label: Text(
                            _isLocatingHouse
                                ? 'Locating...'
                                : 'Use current location instead',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePill(
                              label: 'Start date',
                              value: _startDate == null
                                  ? 'Select'
                                  : DateFormat('MMM d').format(_startDate!),
                              onTap: () => _pickDate(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DatePill(
                              label: 'Return date',
                              value: _endDate == null
                                  ? 'Select'
                                  : DateFormat('MMM d').format(_endDate!),
                              onTap: () => _pickDate(isStart: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _karmaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Karma reward per completed shift',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Watch zone checklist',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._taskCatalog.entries.map((entry) {
                        final selected = _selectedTasks[entry.key] ?? false;
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              _selectedTasks[entry.key] = value;
                            });
                          },
                          title: Text(entry.value.title),
                          subtitle: Text(entry.value.schedule),
                        );
                      }),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _createWatch,
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(
                          _isSubmitting
                              ? 'Creating plan...'
                              : 'Launch vacation watch',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'My watch dashboard',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openDashboard,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open full view'),
                    ),
                    TextButton.icon(
                      onPressed: () => _checkArrivalTrigger(showSuccess: true),
                      icon: const Icon(Icons.radar_outlined),
                      label: const Text('Check arrival'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    watches.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (watches.isEmpty)
                  const _FriendlyEmptyState(
                    title: 'No watch plans yet',
                    message:
                        'Create one above and neighbors will be able to claim daily coverage.',
                  )
                else
                  ...watches.map(
                    (watch) => _OwnerWatchCard(
                      watch: watch,
                      onCancel:
                          watch.status == VacationWatchStatus.completed ||
                              watch.status == VacationWatchStatus.cancelled
                          ? null
                          : () => _repository.cancelWatch(watch.id),
                      activityStream: _repository.watchActivity(watch.id),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCoverageTab() {
    if (_currentUserId.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Sign in to claim shifts and help with coverage.'),
        ),
      );
    }

    return StreamBuilder<List<VacationWatch>>(
      stream: _repository.watchAll(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load available watch shifts: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: [
            _SectionCard(
              title: 'Your claimed shifts',
              subtitle:
                  'Check in, leave a handoff note, or raise an alert during your assigned days.',
              child: myAssigned.isEmpty
                  ? const _FriendlyEmptyState(
                      title: 'No claimed shifts yet',
                      message:
                          'Pick an open day below and it will appear here with your daily actions.',
                    )
                  : Column(
                      children: myAssigned
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 18),
            _SectionCard(
              title: 'Vacation board',
              subtitle:
                  'See who is away, review their open coverage days, and tap a specific day to help.',
              child: watchBoard.isEmpty
                  ? const _FriendlyEmptyState(
                      title: 'No active vacation watches right now',
                      message:
                          'When someone schedules a watch, their trip and open coverage days will show here.',
                    )
                  : Column(
                      children: watchBoard
                          .map(
                            (watch) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _VacationBoardCard(
                                watch: watch,
                                onClaimShift: (shift) =>
                                    _claimShift(watch, shift),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vacation Watch'),
          actions: [
            IconButton(
              tooltip: 'My watch dashboard',
              onPressed: _openDashboard,
              icon: const Icon(Icons.dashboard_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Watch'),
              Tab(text: 'Cover Shifts'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildOwnerTab(), _buildCoverageTab()]),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.karmaPoints,
    required this.isCheckingArrival,
  });

  final int karmaPoints;
  final bool isCheckingArrival;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.watch, AppColors.ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_moon_outlined,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$karmaPoints karma',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Set the roster before you leave',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Task checklists, handoff logs, and arrival wrap-up all live here. Arrival monitoring works while this screen is open.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          if (isCheckingArrival) ...[
            const SizedBox(height: 14),
            Row(
              children: const [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Checking if you are close to home...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(value, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendlyEmptyState extends StatelessWidget {
  const _FriendlyEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.watch),
          const SizedBox(height: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _OwnerWatchCard extends StatelessWidget {
  const _OwnerWatchCard({
    required this.watch,
    required this.activityStream,
    this.onCancel,
  });

  final VacationWatch watch;
  final Stream<List<WatchActivity>> activityStream;
  final Future<void> Function()? onCancel;

  Color _statusColor() {
    switch (watch.status) {
      case VacationWatchStatus.alert:
        return AppColors.alert;
      case VacationWatchStatus.completed:
        return AppColors.safe;
      case VacationWatchStatus.cancelled:
        return AppColors.mutedText;
      case VacationWatchStatus.arrivingHome:
        return AppColors.watch;
      case VacationWatchStatus.active:
        return AppColors.watch;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();
    final dateRange =
        '${DateFormat('MMM d').format(watch.startDate)} - '
        '${DateFormat('MMM d').format(watch.endDate)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        watch.address,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(dateRange),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    watch.status.name,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  label: '${watch.openShiftCount} open shifts',
                  tone: AppColors.watchDim,
                ),
                _MetricPill(
                  label: '${watch.claimedShiftCount} claimed',
                  tone: AppColors.canvas,
                ),
                _MetricPill(
                  label: '${watch.completedShiftCount} completed',
                  tone: AppColors.safeDim,
                ),
                _MetricPill(
                  label: '${watch.karmaReward} karma / shift',
                  tone: AppColors.watchDim,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: watch.completionRatio,
              minHeight: 9,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.safe),
            ),
            const SizedBox(height: 14),
            Text('Tasks', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: watch.tasks
                  .map(
                    (task) => Chip(
                      label: Text(task.title),
                      backgroundColor: task.isCritical
                          ? AppColors.alertDim
                          : AppColors.watchDim,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Text('Roster', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...watch.shifts.map(
              (shift) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${DateFormat('EEE, MMM d').format(shift.startsAt)} • ${shift.label}',
                      ),
                    ),
                    Text(
                      shift.watcherName ??
                          (shift.status == WatchShiftStatus.open
                              ? 'Open'
                              : shift.status.name),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<WatchActivity>>(
              stream: activityStream,
              builder: (context, snapshot) {
                final activity = snapshot.data ?? const <WatchActivity>[];
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Activity feed'),
                  subtitle: Text(
                    activity.isEmpty
                        ? 'No updates yet'
                        : '${activity.length} updates logged',
                  ),
                  children: activity.take(5).map((entry) {
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.canvas,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${entry.actorName} • ${entry.type.name}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'MMM d, HH:mm',
                                ).format(entry.createdAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          if (entry.vibe != null) ...[
                            const SizedBox(height: 6),
                            Text('Vibe: ${entry.vibe!.name}'),
                          ],
                          if (entry.note != null && entry.note!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(entry.note!),
                          ],
                          if (entry.photoUrls.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: entry.photoUrls
                                  .map(
                                    (url) => ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        url,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onCancel!.call(),
                  child: const Text('Cancel watch'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tone,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(watch.address, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('EEE, MMM d').format(shift.startsAt)} • ${shift.label}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: watch.tasks
                .map(
                  (task) => Chip(
                    label: Text(task.title),
                    backgroundColor: task.isCritical
                        ? AppColors.alertDim
                        : AppColors.watchDim,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onCheckIn,
                  child: const Text('Check in'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onComplete,
                  child: const Text('Complete'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRelease,
                  child: const Text('Release shift'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.alert,
                  ),
                  onPressed: onEmergency,
                  child: const Text('Emergency'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VacationBoardCard extends StatelessWidget {
  const _VacationBoardCard({required this.watch, required this.onClaimShift});

  final VacationWatch watch;
  final void Function(WatchShift shift) onClaimShift;

  @override
  Widget build(BuildContext context) {
    final openShifts = watch.shifts.where((shift) => shift.isOpen).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  watch.ownerName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.watchDim,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${watch.karmaReward} karma/day',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(watch.address, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            '${DateFormat('MMM d').format(watch.startDate)} - ${DateFormat('MMM d').format(watch.endDate)} • ${watch.mode == VacationWatchMode.neighborly ? 'Neighborly Help' : 'Pro Care'}',
          ),
          const SizedBox(height: 12),
          Text(
            'Open coverage days',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: openShifts
                .map(
                  (shift) => ActionChip(
                    avatar: const Icon(
                      Icons.event_available_outlined,
                      size: 18,
                    ),
                    label: Text(
                      DateFormat('EEE, MMM d').format(shift.startsAt),
                    ),
                    onPressed: () => onClaimShift(shift),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(
            '${watch.tasks.length} planned tasks',
            style: Theme.of(context).textTheme.bodyMedium,
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
                    label: Text(vibe.name),
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
