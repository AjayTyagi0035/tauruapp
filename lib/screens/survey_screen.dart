import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../constants/survey_options.dart';
import '../models/survey_submission.dart';
import '../services/auth_service.dart';
import '../services/survey_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/image_picker_widget.dart';
import '../widgets/option_selector.dart';
import 'history_screen.dart';
import 'login_screen.dart';

class _StepInfo {
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;

  const _StepInfo(this.label, this.title, this.subtitle, this.icon);
}

const _steps = [
  _StepInfo('Location', 'Administrative Area', 'District, ULB, ward and mohalla', Icons.location_city_outlined),
  _StepInfo('Owner', 'Owner Details', 'Property ID, house and owner information', Icons.person_outline),
  _StepInfo('Property', 'Property Details', 'Construction, usage and utilities', Icons.home_work_outlined),
  _StepInfo('Area', 'Area & Measurements', 'Plot size and floor-wise built-up area', Icons.straighten_outlined),
  _StepInfo('Photos', 'Photos & GPS', 'Property photos, location and remarks', Icons.photo_camera_outlined),
  _StepInfo('Review', 'Review & Submit', 'Check everything before submitting', Icons.fact_check_outlined),
];

class SurveyScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  /// When set, the form opens pre-filled and saving updates this record.
  final SurveySubmission? initial;

  const SurveyScreen({super.key, required this.user, this.initial});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  static const _defaultCenter = LatLng(28.2105, 76.9478); // Tauru
  static const double _mapZoom = 19;

  // Tauru drone tiles (same source as the admin portal's Tauru Map);
  // published for zoom 12–20, upscaled beyond that.
  static const _droneTileUrl =
      'https://cdn.omgauamrit.in/taurudrone/tilestauru/{z}/{x}/{y}.jpg';
  static const _droneMinZoom = 12;
  static const _droneMaxNativeZoom = 20;
  static const _locationStep = 4;

  /// Fixed administrative values for this app; shown read-only in the form.
  static const _fixedValues = {'district': 'Nuh', 'ulbName': 'Tauru'};

  static const _upperFloorKeys = [
    'firstFloorArea',
    'secondFloorArea',
    'thirdFloorArea',
    'fourthFloorArea',
  ];
  static const _upperFloorLabels = [
    'First Floor Area',
    'Second Floor Area',
    'Third Floor Area',
    'Fourth Floor Area',
  ];

  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _mapController = MapController();

  /// Text inputs, keyed by their `surveyor_s_submissions` column name.
  final Map<String, TextEditingController> _c = {
    for (final key in const [
      'district',
      'ulbName',
      'wardNoOrName',
      'mohallaName',
      'propertyId',
      'houseNo',
      'ownerName',
      'fatherOrHusbandName',
      'membersInHouse',
      'mobileNo',
      'address',
      'ifmixed',
      'frontWidthofPlotInFeet',
      'depthofPlotInFeet',
      'totalAreaInFeet',
      'builtUpArea',
      'openArea',
      ..._upperFloorKeys,
      'commercialArea',
      'totalBuiltUpArea',
      'remarks',
    ])
      key: TextEditingController(),
  };

  /// Option inputs, keyed by their `surveyor_s_submissions` column name.
  final Map<String, String?> _choices = {
    'natureOfHouse': null,
    'WidthofRoadInFront': null,
    'Typeofconstruction': null,
    'Useofhouse': null,
    'occupancyStatus': null,
    'floorNo': null,
    'waterConnection': null,
    'sewerConnection': null,
  };

  File? _frontPhoto;
  File? _rightSidePhoto;
  File? _leftSidePhoto;

  // Already-uploaded photos of the record being edited.
  String? _frontPhotoUrl;
  String? _rightSidePhotoUrl;
  String? _leftSidePhotoUrl;

  LatLng? _location;
  bool _showMap = false;
  bool _showDrone = true;
  bool _isLocating = false;

  // Already-surveyed houses shown on the map; loaded when the map first opens.
  List<MapHouse>? _mapHouses;
  bool _loadingHouses = false;

  int _currentStep = 0;
  int _maxReachedStep = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) _prefill(initial);
    _applyFixedValues();
    for (final key in [
      'frontWidthofPlotInFeet',
      'depthofPlotInFeet',
      'builtUpArea',
      ..._upperFloorKeys,
    ]) {
      _c[key]!.addListener(_recomputeAreas);
    }
    if (_location == null) _useCurrentLocation(silent: true);
  }

  bool get _isEdit => widget.initial != null;

  void _prefill(SurveySubmission s) {
    void set(String key, Object? value) {
      if (value == null) return;
      _c[key]!.text = value is double ? _format(value) : '$value';
    }

    set('wardNoOrName', s.wardNoOrName);
    set('mohallaName', s.mohallaName);
    set('propertyId', s.propertyId);
    set('houseNo', s.houseNo);
    set('ownerName', s.ownerName);
    set('fatherOrHusbandName', s.fatherOrHusbandName);
    set('membersInHouse', s.membersInHouse);
    set('mobileNo', s.mobileNo);
    set('address', s.address);
    set('ifmixed', s.ifmixed);
    set('frontWidthofPlotInFeet', s.frontWidthofPlotInFeet);
    set('depthofPlotInFeet', s.depthofPlotInFeet);
    set('totalAreaInFeet', s.totalAreaInFeet);
    set('builtUpArea', s.builtUpArea);
    set('openArea', s.openArea);
    set('firstFloorArea', s.firstFloorArea);
    set('secondFloorArea', s.secondFloorArea);
    set('thirdFloorArea', s.thirdFloorArea);
    set('fourthFloorArea', s.fourthFloorArea);
    set('commercialArea', s.commercialArea);
    set('totalBuiltUpArea', s.totalBuiltUpArea);
    set('remarks', s.remarks);

    _choices
      ..['natureOfHouse'] = s.natureOfHouse
      ..['WidthofRoadInFront'] = s.widthofRoadInFront
      ..['Typeofconstruction'] = s.typeofconstruction
      ..['Useofhouse'] = s.useofhouse
      ..['occupancyStatus'] = s.occupancyStatus
      ..['floorNo'] = s.floorNo
      ..['waterConnection'] = s.waterConnection
      ..['sewerConnection'] = s.sewerConnection;

    _frontPhotoUrl = s.frontPhotoUrl;
    _rightSidePhotoUrl = s.rightSidePhotoUrl;
    _leftSidePhotoUrl = s.leftSidePhotoUrl;

    if (s.dataLat != null && s.dataLng != null) {
      _location = LatLng(s.dataLat!, s.dataLng!);
    }
    // Every step already has data, so allow jumping straight to any of them.
    _maxReachedStep = _steps.length - 1;
  }

  @override
  void dispose() {
    for (final controller in _c.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFixedValues() {
    _fixedValues.forEach((key, value) => _c[key]!.text = value);
  }

  // ── Derived values ─────────────────────────────────────────────────────────

  double? _num(String key) => double.tryParse(_c[key]!.text.trim());

  String? _text(String key) {
    final value = _c[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  int get _upperFloors =>
      math.max(0, SurveyOptions.floorNo.indexOf(_choices['floorNo'] ?? ''));

  bool get _isMixedUse => _choices['Useofhouse'] == SurveyOptions.mixedUse;

  bool get _hasCommercialArea =>
      SurveyOptions.usesWithCommercialArea.contains(_choices['Useofhouse']);

  String _format(double value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  void _recomputeAreas() {
    final front = _num('frontWidthofPlotInFeet');
    final depth = _num('depthofPlotInFeet');
    final builtUp = _num('builtUpArea');

    final total = front != null && depth != null ? front * depth : null;
    final open = total != null && builtUp != null ? total - builtUp : null;
    final floors =
        _upperFloorKeys.take(_upperFloors).map(_num).whereType<double>();
    final totalBuiltUp =
        builtUp == null && floors.isEmpty
            ? null
            : (builtUp ?? 0) + floors.fold<double>(0, (sum, v) => sum + v);

    void write(String key, double? value) {
      final text = value == null ? '' : _format(value);
      if (_c[key]!.text != text) _c[key]!.text = text;
    }

    write('totalAreaInFeet', total);
    write('openArea', open);
    write('totalBuiltUpArea', totalBuiltUp);
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _useCurrentLocation({bool silent = false}) async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent) _showSnack('Please turn on device location.', AppColors.warning);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent) _showSnack('Location permission denied.', AppColors.warning);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;

      final point = LatLng(position.latitude, position.longitude);
      setState(() => _location = point);
      if (_showMap) _mapController.move(point, _mapZoom);
    } catch (_) {
      if (!silent) _showSnack('Could not get current location.', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _loadMapHouses({bool force = false}) async {
    if (_loadingHouses || (_mapHouses != null && !force)) return;
    setState(() => _loadingHouses = true);
    try {
      final houses = await SurveyService.fetchMapHouses();
      if (!mounted) return;
      // The record being edited is the pin itself, not a separate house.
      final editingId = widget.initial?.id;
      setState(() => _mapHouses = houses.where((h) => h.id != editingId).toList());
    } catch (_) {
      if (mounted) _showSnack('Could not load surveyed houses.', AppColors.warning);
    } finally {
      if (mounted) setState(() => _loadingHouses = false);
    }
  }

  List<Marker> _houseMarkers() {
    return [
      for (final h in _mapHouses ?? const <MapHouse>[])
        Marker(
          point: LatLng(h.latitude, h.longitude),
          width: 22,
          height: 22,
          child: GestureDetector(
            onTap: () => _showSnack(
              'Already surveyed: House ${h.houseNo ?? '—'} · ${h.ownerName ?? 'Unnamed owner'}'
              '${h.wardNoOrName != null ? ' · Ward ${h.wardNoOrName}' : ''}',
              AppColors.primaryDark,
            ),
            // Same red dot as the portal's map; the padding enlarges the tap target.
            child: Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFEA4335),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  bool _validateCurrentStep() {
    if (!(_formKey.currentState?.validate() ?? true)) {
      _showSnack('Please fix the highlighted fields.', AppColors.warning);
      return false;
    }
    if (_currentStep == _locationStep && _location == null) {
      _showSnack('Please capture the property location.', AppColors.warning);
      return false;
    }
    return true;
  }

  void _goToStep(int step) {
    if (_isSubmitting || step == _currentStep) return;
    if (step > _currentStep && !_validateCurrentStep()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _currentStep = step;
      _maxReachedStep = math.max(_maxReachedStep, step);
      _showMap = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _onPrimaryAction() {
    if (_currentStep == _steps.length - 1) {
      _submit();
    } else {
      _goToStep(_currentStep + 1);
    }
  }

  // ── Submit / reset ─────────────────────────────────────────────────────────

  SurveySubmission _buildSubmission({
    String? frontPhotoUrl,
    String? rightSidePhotoUrl,
    String? leftSidePhotoUrl,
  }) {
    final floors = _upperFloors;
    double? floorArea(int index) =>
        index < floors ? _num(_upperFloorKeys[index]) : null;

    return SurveySubmission(
      ulbName: _text('ulbName'),
      district: _text('district'),
      mohallaName: _text('mohallaName'),
      wardNoOrName: _text('wardNoOrName'),
      propertyId: _text('propertyId'),
      houseNo: _text('houseNo'),
      ownerName: _text('ownerName'),
      fatherOrHusbandName: _text('fatherOrHusbandName'),
      membersInHouse: int.tryParse(_c['membersInHouse']!.text.trim()),
      address: _text('address'),
      mobileNo: _text('mobileNo'),
      natureOfHouse: _choices['natureOfHouse'],
      widthofRoadInFront: _choices['WidthofRoadInFront'],
      typeofconstruction: _choices['Typeofconstruction'],
      useofhouse: _choices['Useofhouse'],
      frontWidthofPlotInFeet: _num('frontWidthofPlotInFeet'),
      depthofPlotInFeet: _num('depthofPlotInFeet'),
      totalAreaInFeet: _num('totalAreaInFeet'),
      builtUpArea: _num('builtUpArea'),
      openArea: _num('openArea'),
      ifmixed: _isMixedUse ? _text('ifmixed') : null,
      firstFloorArea: floorArea(0),
      secondFloorArea: floorArea(1),
      thirdFloorArea: floorArea(2),
      fourthFloorArea: floorArea(3),
      commercialArea: _hasCommercialArea ? _num('commercialArea') : null,
      totalBuiltUpArea: _num('totalBuiltUpArea'),
      occupancyStatus: _choices['occupancyStatus'],
      frontPhotoUrl: frontPhotoUrl,
      rightSidePhotoUrl: rightSidePhotoUrl,
      leftSidePhotoUrl: leftSidePhotoUrl,
      dataLat: _location?.latitude,
      dataLng: _location?.longitude,
      waterConnection: _choices['waterConnection'],
      sewerConnection: _choices['sewerConnection'],
      submittedBy: int.tryParse('${widget.user['id']}'),
      remarks: _text('remarks'),
      floorNo: _choices['floorNo'],
    );
  }

  List<_PhotoSlot> get _photoSlots => [
    _PhotoSlot('Front photo', () => _frontPhoto, (url) {
      _frontPhotoUrl = url;
      _frontPhoto = null;
    }),
    _PhotoSlot('Right side photo', () => _rightSidePhoto, (url) {
      _rightSidePhotoUrl = url;
      _rightSidePhoto = null;
    }),
    _PhotoSlot('Left side photo', () => _leftSidePhoto, (url) {
      _leftSidePhotoUrl = url;
      _leftSidePhoto = null;
    }),
  ];

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_location == null) {
      _goToStep(_locationStep);
      _showSnack('Please capture the property location.', AppColors.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Upload newly picked photos; keep the existing URL otherwise. Once a
      // photo is uploaded its URL is kept, so a retry doesn't upload it again.
      for (final slot in _photoSlots) {
        final file = slot.file();
        if (file == null) continue;
        final url = await SurveyService.uploadPhoto(file);
        if (!mounted) return;
        if (url == null) {
          _showSnack('${slot.label} upload failed. Please try again.', AppColors.error);
          return;
        }
        setState(() => slot.uploaded(url));
      }

      final submission = _buildSubmission(
        frontPhotoUrl: _frontPhotoUrl,
        rightSidePhotoUrl: _rightSidePhotoUrl,
        leftSidePhotoUrl: _leftSidePhotoUrl,
      );
      final error =
          _isEdit
              ? await SurveyService.updateSurvey(widget.initial!.id!, submission)
              : await SurveyService.submitSurvey(submission);
      if (!mounted) return;

      if (error != null) {
        _showSnack(error, AppColors.error);
        return;
      }

      if (_isEdit) {
        Navigator.of(context).pop(true);
        return;
      }
      // The new house should appear on the map next time it's opened.
      _mapHouses = null;
      await _showSuccessDialog();
      _resetForm();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    for (final controller in _c.values) {
      controller.clear();
    }
    setState(() {
      _choices.updateAll((_, __) => null);
      _frontPhoto = null;
      _rightSidePhoto = null;
      _leftSidePhoto = null;
      _frontPhotoUrl = null;
      _rightSidePhotoUrl = null;
      _leftSidePhotoUrl = null;
      _location = null;
      _showMap = false;
      _currentStep = 0;
      _maxReachedStep = 0;
    });
    _formKey.currentState?.reset();
    _applyFixedValues();
    _useCurrentLocation(silent: true);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Start a new survey?'),
            content: const Text('All data entered in the current form will be cleared.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
    if (confirmed == true) _resetForm();
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            icon: const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFDCFCE7),
              child: Icon(Icons.check_rounded, size: 36, color: AppColors.success),
            ),
            title: const Text('Survey Submitted'),
            content: const Text(
              'The property survey was submitted successfully.',
              textAlign: TextAlign.center,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Start New Survey'),
                ),
              ),
            ],
          ),
    );
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HistoryScreen(user: widget.user)),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => _ProfileSheet(
            user: widget.user,
            onLogout: () async {
              Navigator.pop(sheetContext);
              await AuthService.logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
    );
  }

  // ── Field helpers ──────────────────────────────────────────────────────────

  static final _decimalFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}'),
  );

  String? _required(String? value, String label) =>
      value == null || value.trim().isEmpty ? '$label is required' : null;

  Widget _field(
    String key,
    String label, {
    IconData? icon,
    bool required = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    int? maxLength,
    String? suffixText,
    String? helperText,
    bool readOnly = false,
  }) {
    return CustomTextField(
      controller: _c[key]!,
      label: required ? '$label *' : label,
      prefixIcon: icon,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      suffixText: suffixText,
      helperText: helperText,
      readOnly: readOnly,
      textCapitalization:
          keyboardType == TextInputType.text
              ? TextCapitalization.words
              : TextCapitalization.none,
      validator: validator ?? (required ? (v) => _required(v, label) : null),
    );
  }

  Widget _areaField(String key, String label, {bool readOnly = false, String? helperText, String? Function(String?)? validator}) {
    return _field(
      key,
      label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimalFormatter],
      suffixText: 'sq ft',
      readOnly: readOnly,
      helperText: helperText,
      validator: validator,
    );
  }

  Widget _gap([double height = 14]) => SizedBox(height: height);

  // ── Steps ──────────────────────────────────────────────────────────────────

  Widget _buildLocationStep() {
    return _SectionCard(
      title: 'Administrative Area',
      icon: Icons.location_city_outlined,
      children: [
        _field('district', 'District', icon: Icons.map_outlined, required: true, readOnly: true),
        _gap(),
        _field('ulbName', 'ULB Name', icon: Icons.account_balance_outlined, required: true, readOnly: true),
        _gap(),
        _field('wardNoOrName', 'Ward No. / Name', icon: Icons.grid_view_outlined, required: true),
        _gap(),
        _field('mohallaName', 'Mohalla Name', icon: Icons.holiday_village_outlined),
      ],
    );
  }

  Widget _buildOwnerStep() {
    return Column(
      children: [
        _SectionCard(
          title: 'Property Identification',
          icon: Icons.tag,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _field('propertyId', 'Property ID', keyboardType: TextInputType.visiblePassword)),
                const SizedBox(width: 12),
                Expanded(child: _field('houseNo', 'House No.', keyboardType: TextInputType.visiblePassword)),
              ],
            ),
          ],
        ),
        _gap(),
        _SectionCard(
          title: 'Owner Information',
          icon: Icons.person_outline,
          children: [
            _field('ownerName', 'Owner Name', icon: Icons.person_outline, required: true),
            _gap(),
            _field('fatherOrHusbandName', 'Father / Husband Name', icon: Icons.family_restroom_outlined),
            _gap(),
            _field(
              'mobileNo',
              'Mobile No.',
              icon: Icons.phone_android_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isNotEmpty && value.length != 10) {
                  return 'Enter a valid 10-digit mobile number';
                }
                return null;
              },
            ),
            _gap(),
            _field(
              'membersInHouse',
              'Members in House',
              icon: Icons.groups_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
            ),
            _gap(),
            _field('address', 'Address', icon: Icons.home_outlined, maxLines: 2),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertyStep() {
    void choose(String key, String? value) {
      setState(() => _choices[key] = value);
      if (key == 'floorNo') _recomputeAreas();
    }

    return Column(
      children: [
        _SectionCard(
          title: 'Construction',
          icon: Icons.foundation_outlined,
          children: [
            ChipSelector(
              label: 'Nature of House',
              icon: Icons.house_outlined,
              options: SurveyOptions.natureOfHouse,
              value: _choices['natureOfHouse'],
              onChanged: (v) => choose('natureOfHouse', v),
            ),
            _gap(18),
            AppDropdown(
              label: 'Type of Construction',
              icon: Icons.construction_outlined,
              options: SurveyOptions.typeOfConstruction,
              value: _choices['Typeofconstruction'],
              onChanged: (v) => choose('Typeofconstruction', v),
            ),
            _gap(),
            AppDropdown(
              label: 'Width of Road in Front',
              icon: Icons.add_road_outlined,
              options: SurveyOptions.widthOfRoadInFront,
              value: _choices['WidthofRoadInFront'],
              onChanged: (v) => choose('WidthofRoadInFront', v),
            ),
            _gap(18),
            ChipSelector(
              label: 'Number of Floors',
              icon: Icons.layers_outlined,
              options: SurveyOptions.floorNo,
              value: _choices['floorNo'],
              onChanged: (v) => choose('floorNo', v),
            ),
          ],
        ),
        _gap(),
        _SectionCard(
          title: 'Usage',
          icon: Icons.business_outlined,
          children: [
            AppDropdown(
              label: 'Use of House',
              icon: Icons.category_outlined,
              options: SurveyOptions.useOfHouse,
              value: _choices['Useofhouse'],
              onChanged: (v) => choose('Useofhouse', v),
            ),
            if (_isMixedUse) ...[
              _gap(),
              _field('ifmixed', 'If Mixed, Specify Use', icon: Icons.call_split_outlined, required: true),
            ],
            _gap(18),
            ChipSelector(
              label: 'Occupancy Status',
              icon: Icons.key_outlined,
              options: SurveyOptions.occupancyStatus,
              value: _choices['occupancyStatus'],
              onChanged: (v) => choose('occupancyStatus', v),
            ),
          ],
        ),
        _gap(),
        _SectionCard(
          title: 'Utilities',
          icon: Icons.plumbing_outlined,
          children: [
            ChipSelector(
              label: 'Water Connection',
              icon: Icons.water_drop_outlined,
              options: SurveyOptions.yesNo,
              value: _choices['waterConnection'],
              onChanged: (v) => choose('waterConnection', v),
            ),
            _gap(18),
            ChipSelector(
              label: 'Sewer Connection',
              icon: Icons.water_outlined,
              options: SurveyOptions.yesNo,
              value: _choices['sewerConnection'],
              onChanged: (v) => choose('sewerConnection', v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAreaStep() {
    final upperFloors = _upperFloors;
    return Column(
      children: [
        _SectionCard(
          title: 'Plot',
          icon: Icons.crop_square_outlined,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    'frontWidthofPlotInFeet',
                    'Front Width',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimalFormatter],
                    suffixText: 'ft',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 18, 8, 0),
                  child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                ),
                Expanded(
                  child: _field(
                    'depthofPlotInFeet',
                    'Depth',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [_decimalFormatter],
                    suffixText: 'ft',
                  ),
                ),
              ],
            ),
            _gap(),
            _areaField('totalAreaInFeet', 'Total Plot Area', readOnly: true, helperText: 'Auto: front width × depth'),
          ],
        ),
        _gap(),
        _SectionCard(
          title: 'Built-up Area',
          icon: Icons.apartment_outlined,
          children: [
            _areaField(
              'builtUpArea',
              'Built-up Area (Ground Floor)',
              validator: (v) {
                final built = double.tryParse(v?.trim() ?? '');
                final total = _num('totalAreaInFeet');
                if (built != null && total != null && built > total) {
                  return 'Cannot exceed total plot area';
                }
                return null;
              },
            ),
            for (var i = 0; i < upperFloors; i++) ...[
              _gap(),
              _areaField(_upperFloorKeys[i], _upperFloorLabels[i]),
            ],
            if (upperFloors == 0) ...[
              _gap(10),
              _InfoBanner(
                text: 'Upper floor fields appear after selecting the number of floors in the Property step.',
              ),
            ],
            if (_hasCommercialArea) ...[
              _gap(),
              _areaField('commercialArea', 'Commercial Area'),
            ],
            _gap(),
            _areaField('openArea', 'Open Area', readOnly: true, helperText: 'Auto: plot area − ground built-up'),
            _gap(),
            _areaField('totalBuiltUpArea', 'Total Built-up Area', readOnly: true, helperText: 'Auto: ground + all upper floors'),
          ],
        ),
        _gap(),
        ListenableBuilder(
          listenable: Listenable.merge([
            _c['totalAreaInFeet'],
            _c['totalBuiltUpArea'],
            _c['openArea'],
          ]),
          builder:
              (_, __) => _AreaSummary(
                plot: _c['totalAreaInFeet']!.text,
                builtUp: _c['totalBuiltUpArea']!.text,
                open: _c['openArea']!.text,
              ),
        ),
      ],
    );
  }

  Widget _buildPhotosStep() {
    return Column(
      children: [
        _SectionCard(
          title: 'Property Photos',
          icon: Icons.photo_camera_outlined,
          children: [
            ImagePickerWidget(
              label: 'Front Photo',
              image: _frontPhoto,
              imageUrl: _frontPhotoUrl,
              height: 180,
              onImageChanged: (f) => setState(() {
                _frontPhoto = f;
                if (f == null) _frontPhotoUrl = null;
              }),
            ),
            _gap(),
            Row(
              children: [
                Expanded(
                  child: ImagePickerWidget(
                    label: 'Right Side',
                    image: _rightSidePhoto,
                    imageUrl: _rightSidePhotoUrl,
                    height: 130,
                    onImageChanged: (f) => setState(() {
                      _rightSidePhoto = f;
                      if (f == null) _rightSidePhotoUrl = null;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ImagePickerWidget(
                    label: 'Left Side',
                    image: _leftSidePhoto,
                    imageUrl: _leftSidePhotoUrl,
                    height: 130,
                    onImageChanged: (f) => setState(() {
                      _leftSidePhoto = f;
                      if (f == null) _leftSidePhotoUrl = null;
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
        _gap(),
        _buildGpsCard(),
        _gap(),
        _SectionCard(
          title: 'Remarks',
          icon: Icons.notes_outlined,
          children: [
            _field('remarks', 'Remarks', maxLines: 3),
          ],
        ),
      ],
    );
  }

  Widget _buildGpsCard() {
    final location = _location;
    return _SectionCard(
      title: 'GPS Location *',
      icon: Icons.my_location_outlined,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: location == null ? const Color(0xFFFFF7ED) : AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                location == null ? Icons.location_disabled_outlined : Icons.location_on,
                color: location == null ? AppColors.warning : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child:
                    location == null
                        ? const Text(
                          'Location not captured yet',
                          style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lat  ${location.latitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lng  ${location.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ),
        _gap(12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isLocating ? null : () => _useCurrentLocation(),
                icon:
                    _isLocating
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                        : const Icon(Icons.gps_fixed, size: 18),
                label: const Text('Current'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _showMap = !_showMap);
                  if (_showMap) _loadMapHouses();
                },
                icon: Icon(_showMap ? Icons.keyboard_arrow_up : Icons.map_outlined, size: 18),
                label: Text(_showMap ? 'Hide Map' : 'Pick on Map'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        if (_showMap) ...[
          _gap(12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 320,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: location ?? _defaultCenter,
                      initialZoom: location == null ? 15 : _mapZoom,
                      minZoom: 4,
                      maxZoom: 22,
                      onPositionChanged: (camera, hasGesture) {
                        if (hasGesture) setState(() => _location = camera.center);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                        subdomains: const ['0', '1', '2', '3'],
                        userAgentPackageName: 'com.example.tauruapp',
                        maxZoom: 22,
                      ),
                      if (_showDrone)
                        TileLayer(
                          urlTemplate: _droneTileUrl,
                          userAgentPackageName: 'com.example.tauruapp',
                          minZoom: _droneMinZoom.toDouble(),
                          maxNativeZoom: _droneMaxNativeZoom,
                          maxZoom: 22,
                          // Outside the drone coverage tiles 404; just leave them blank.
                          errorTileCallback: (_, __, ___) {},
                        ),
                      MarkerLayer(markers: _houseMarkers()),
                    ],
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _HouseCountChip(
                      loading: _loadingHouses,
                      count: _mapHouses?.length,
                      onRetry: () => _loadMapHouses(force: true),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FilterChip(
                      selected: _showDrone,
                      onSelected: (v) => setState(() => _showDrone = v),
                      avatar: const Icon(Icons.satellite_alt_outlined, size: 16),
                      label: const Text('Drone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      selectedColor: AppColors.surfaceTint,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.location_on, size: 44, color: Colors.amber),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Drag the map to place the pin on the property',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    String show(String? value) => value == null || value.isEmpty ? '—' : value;
    String area(String key) {
      final value = _text(key);
      return value == null ? '—' : '$value sq ft';
    }

    final upperFloors = _upperFloors;
    final photoCount = [
      _frontPhoto ?? _frontPhotoUrl,
      _rightSidePhoto ?? _rightSidePhotoUrl,
      _leftSidePhoto ?? _leftSidePhotoUrl,
    ].where((p) => p != null && p != '').length;

    return Column(
      children: [
        _ReviewCard(
          title: 'Administrative Area',
          icon: Icons.location_city_outlined,
          onEdit: () => _goToStep(0),
          rows: {
            'District': show(_text('district')),
            'ULB Name': show(_text('ulbName')),
            'Ward No. / Name': show(_text('wardNoOrName')),
            'Mohalla': show(_text('mohallaName')),
          },
        ),
        _gap(12),
        _ReviewCard(
          title: 'Owner Details',
          icon: Icons.person_outline,
          onEdit: () => _goToStep(1),
          rows: {
            'Property ID': show(_text('propertyId')),
            'House No.': show(_text('houseNo')),
            'Owner Name': show(_text('ownerName')),
            'Father / Husband': show(_text('fatherOrHusbandName')),
            'Mobile No.': show(_text('mobileNo')),
            'Members': show(_text('membersInHouse')),
            'Address': show(_text('address')),
          },
        ),
        _gap(12),
        _ReviewCard(
          title: 'Property Details',
          icon: Icons.home_work_outlined,
          onEdit: () => _goToStep(2),
          rows: {
            'Nature of House': show(_choices['natureOfHouse']),
            'Construction': show(_choices['Typeofconstruction']),
            'Road Width': show(_choices['WidthofRoadInFront']),
            'Floors': show(_choices['floorNo']),
            'Use of House': show(_choices['Useofhouse']),
            if (_isMixedUse) 'Mixed Use': show(_text('ifmixed')),
            'Occupancy': show(_choices['occupancyStatus']),
            'Water Connection': show(_choices['waterConnection']),
            'Sewer Connection': show(_choices['sewerConnection']),
          },
        ),
        _gap(12),
        _ReviewCard(
          title: 'Area & Measurements',
          icon: Icons.straighten_outlined,
          onEdit: () => _goToStep(3),
          rows: {
            'Front × Depth':
                '${show(_text('frontWidthofPlotInFeet'))} × ${show(_text('depthofPlotInFeet'))} ft',
            'Total Plot Area': area('totalAreaInFeet'),
            'Built-up (Ground)': area('builtUpArea'),
            for (var i = 0; i < upperFloors; i++)
              _upperFloorLabels[i].replaceFirst(' Area', ''): area(_upperFloorKeys[i]),
            if (_hasCommercialArea) 'Commercial Area': area('commercialArea'),
            'Open Area': area('openArea'),
            'Total Built-up': area('totalBuiltUpArea'),
          },
        ),
        _gap(12),
        _ReviewCard(
          title: 'Photos & GPS',
          icon: Icons.photo_camera_outlined,
          onEdit: () => _goToStep(4),
          rows: {
            'Photos': '$photoCount of 3 added',
            'Latitude': _location?.latitude.toStringAsFixed(6) ?? '—',
            'Longitude': _location?.longitude.toStringAsFixed(6) ?? '—',
            'Remarks': show(_text('remarks')),
          },
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildLocationStep();
      case 1:
        return _buildOwnerStep();
      case 2:
        return _buildPropertyStep();
      case 3:
        return _buildAreaStep();
      case 4:
        return _buildPhotosStep();
      default:
        return _buildReviewStep();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;
    final name = (widget.user['name'] as String?)?.trim();

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Edit Survey #${widget.initial!.id}' : 'Tauru App',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            Text(
              _isEdit ? 'Update and save changes' : 'Property Survey',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: _isEdit ? null : [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'My surveys',
            onPressed: _isSubmitting ? null : _openHistory,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'New survey',
            onPressed: _isSubmitting ? null : _confirmReset,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _showProfileSheet,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Text(
                  name != null && name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: AbsorbPointer(
          absorbing: _isSubmitting,
          child: Column(
            children: [
              _StepHeader(
                current: _currentStep,
                maxReached: _maxReachedStep,
                onTap: _goToStep,
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Text(
                      'STEP ${_currentStep + 1} OF ${_steps.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(step.subtitle, style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    _buildCurrentStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 12, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : () => _goToStep(_currentStep - 1),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _onPrimaryAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: isLast ? AppColors.success : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child:
                        _isSubmitting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLast
                                      ? (_isEdit ? 'Save Changes' : 'Submit Survey')
                                      : 'Next: ${_steps[_currentStep + 1].label}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Icon(isLast ? Icons.cloud_upload_outlined : Icons.arrow_forward, size: 18),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────────────

class _HouseCountChip extends StatelessWidget {
  final bool loading;
  final int? count;
  final VoidCallback onRetry;

  const _HouseCountChip({required this.loading, required this.count, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final failed = !loading && count == null;
    return GestureDetector(
      onTap: failed ? onRetry : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Color(0xFFEA4335), shape: BoxShape.circle),
              ),
            const SizedBox(width: 6),
            Text(
              loading
                  ? 'Loading houses…'
                  : failed
                  ? 'Tap to retry'
                  : '$count surveyed',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoSlot {
  final String label;
  final File? Function() file;
  final void Function(String url) uploaded;

  const _PhotoSlot(this.label, this.file, this.uploaded);
}

class _StepHeader extends StatelessWidget {
  final int current;
  final int maxReached;
  final ValueChanged<int> onTap;

  const _StepHeader({
    required this.current,
    required this.maxReached,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      child: Row(
        children: List.generate(_steps.length, (i) {
          final isDone = i < current;
          final isCurrent = i == current;
          final reachable = i <= maxReached;
          final active = isDone || isCurrent;

          Widget connector(bool visible, bool filled) => Expanded(
            child: Container(
              height: 2,
              color:
                  !visible
                      ? Colors.transparent
                      : filled
                      ? AppColors.primary
                      : AppColors.border,
            ),
          );

          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: reachable ? () => onTap(i) : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      connector(i > 0, i <= current),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isCurrent ? 36 : 30,
                        height: isCurrent ? 36 : 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? AppColors.primary : Colors.white,
                          border: Border.all(
                            color: active ? AppColors.primary : AppColors.border,
                            width: 2,
                          ),
                          boxShadow:
                              isCurrent
                                  ? [
                                    BoxShadow(
                                      color: AppColors.primary.withAlpha(70),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Icon(
                          isDone ? Icons.check : _steps[i].icon,
                          size: isCurrent ? 18 : 15,
                          color: active ? Colors.white : AppColors.textMuted,
                        ),
                      ),
                      connector(i < _steps.length - 1, i < current),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _steps[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primaryDark : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3EEEC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaSummary extends StatelessWidget {
  final String plot;
  final String builtUp;
  final String open;

  const _AreaSummary({
    required this.plot,
    required this.builtUp,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(
            value.isEmpty ? '—' : value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'AREA SUMMARY (SQ FT)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              tile('Plot', plot),
              tile('Total Built-up', builtUp),
              tile('Open', open),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onEdit;
  final Map<String, String> rows;

  const _ReviewCard({
    required this.title,
    required this.icon,
    required this.onEdit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      children: [
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ),
      ],
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  const _ProfileSheet({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] as String?)?.trim();
    final displayName = name == null || name.isEmpty ? 'Surveyor' : name;
    final mobile = user['mobile']?.toString() ?? '—';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white24,
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 19,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(mobile, style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout, color: AppColors.error, size: 20),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onLogout,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
