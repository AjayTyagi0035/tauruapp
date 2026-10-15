import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/image_picker_widget.dart';
import '../widgets/property_tax_calculator.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

// ── Property tax rate lookup ─────────────────────────────────────────────────
const _kRateTable = {
  '3 -9 meter': {
    'rcc &rbc pakka': 0.7, 'semi pakka': 0.6, 'kachha': 0.5, 'open plot': 0.12,
  },
  '9 -12 meter': {
    'rcc &rbc pakka': 0.8, 'semi pakka': 0.7, 'kachha': 0.6, 'open plot': 0.15,
  },
  '12 -24 meter': {
    'rcc &rbc pakka': 0.9, 'semi pakka': 0.8, 'kachha': 0.7, 'open plot': 0.20,
  },
  '24 -more than  meter': {
    'rcc &rbc pakka': 1.0, 'semi pakka': 0.9, 'kachha': 0.8, 'open plot': 0.25,
  },
};

class MapScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const MapScreen({super.key, required this.user});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double _focusedMapZoom = 20.0;
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _controllers = {
    'district_id': TextEditingController(),
    'ulb_id': TextEditingController(),
    'ward_id': TextEditingController(),
    'mohalla_id': TextEditingController(),
    'old_ward_no': TextEditingController(),
    'old_ward_name': TextEditingController(),
    'old_moholla_name': TextEditingController(),
    'old_house_no': TextEditingController(),
    'old_owner_name': TextEditingController(),
    'old_father_husband_name': TextEditingController(),
    'old_house_tax': TextEditingController(),
    'old_house_tax_arrear': TextEditingController(),
    'house_tax_arrear_2025_26': TextEditingController(),
    'old_water_tax': TextEditingController(),
    'water_tax_arrear_2025_26': TextEditingController(),
    'new_house_no': TextEditingController(),
    'owner_name': TextEditingController(),
    'father_husband_name': TextEditingController(),
    'mobile_no': TextEditingController(),
    'address': TextEditingController(),
    'road_location_width': TextEditingController(),
    'rate': TextEditingController(),
    'nature_of_house': TextEditingController(),
    'property_type': TextEditingController(),
    'property_use_as': TextEditingController(),
    'construction_year': TextEditingController(),
    'rebate_type': TextEditingController(),
    'financial_year': TextEditingController(),
    'front_feet': TextEditingController(),
    'depth_feet': TextEditingController(),
    'total_plot_area_sqft': TextEditingController(),
    'no_of_floors': TextEditingController(),
    'ground_floor_area': TextEditingController(),
    'first_floor_area': TextEditingController(),
    'second_floor_area': TextEditingController(),
    'third_floor_area': TextEditingController(),
    'total_residential_area': TextEditingController(),
    'total_commercial_area': TextEditingController(),
    'empty_area': TextEditingController(),
    'total_current_arv': TextEditingController(),
    'house_tax_current': TextEditingController(),
    'house_tax_arrear': TextEditingController(),
    'house_tax_interest': TextEditingController(),
    'total_house_tax': TextEditingController(),
    'water_tax_current': TextEditingController(),
    'water_tax_arrear': TextEditingController(),
    'water_tax_interest': TextEditingController(),
    'total_water_tax': TextEditingController(),
    'watertank_present': TextEditingController(text: 'False'),
    'watertank_tax_current': TextEditingController(),
    'watertank_tax_arrear': TextEditingController(),
    'watertank_tax_interest': TextEditingController(),
    'total_watertank_tax': TextEditingController(),
    'total_tax': TextEditingController(),
    'remarks': TextEditingController(),
  };

  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _centerPosition = const LatLng(29.4, 77.17);
  File? _surveyPhoto;
  File? _streetLightPhoto;
  String? _surveyPhotoUrl;
  String? _streetLightPhotoUrl;
  bool _showMap = false;
  bool _showCustomTiles = true;
  bool _isSearchingProperty = false;
  bool _isSubmitting = false;
  bool _isRefreshingLocation = false;
  bool _isFromSearchOrHistory = false;
  final ScrollController _formScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final TextEditingController _historySearchController = TextEditingController();
  int? _currentSurveyId;

  // ── Property tax computed values ────────────────────────────────────────────
  double? _computedRate;
  double? _computedArv;
  double? _computedAdjustedArv;
  String _computedAdjLabel = '';
  String _computedArvFormula = '';

  int _currentStep = 0;
  final int _totalSteps = 6;
  bool _isLoadingLocationInfo = true;

  String? _selectedDistrictId;
  String? _selectedUlbId;

  List<dynamic> _wardsList = [];
  List<dynamic> _mohallasList = [];
  String? _selectedWardId;
  String? _selectedMohallaId;
  List<Map<String, dynamic>> _surveyHistory = [];
  bool _isLoadingHistory = false;
  bool _isLoadingMoreHistory = false;
  bool _hasMoreHistory = true;
  int _historyPage = 1;
  static const int _historyPageSize = 20;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    for (final key in ['old_ward_no', 'old_moholla_name', 'old_house_no']) {
      _controllers[key]!.addListener(_onSearchFieldsChanged);
    }
    for (final key in [
      'front_feet',
      'depth_feet',
      'ground_floor_area',
      'total_commercial_area',
      'first_floor_area',
      'second_floor_area',
      'third_floor_area',
    ]) {
      _controllers[key]!.addListener(_updateComputedAreaFields);
    }
    for (final key in _kTaxListenerKeys) {
      _controllers[key]!.addListener(_recalculatePropertyTax);
    }
    _historySearchController.addListener(_onSearchFieldsChanged);
    _historyScrollController.addListener(_onHistoryScroll);
    _fetchAutoFillLocationData();
    _refreshCurrentLocation();
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    final pos = _historyScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 &&
        !_isLoadingMoreHistory &&
        _hasMoreHistory &&
        !_isLoadingHistory) {
      _loadMoreHistory();
    }
  }

  // ── Property tax calculation ─────────────────────────────────────────────────
  static const _kTaxListenerKeys = [
    'road_location_width', 'nature_of_house', 'property_type',
    'property_use_as', 'construction_year',
    'total_residential_area', 'total_commercial_area', 'empty_area',
    'house_tax_arrear',
    'water_tax_arrear',
    'watertank_present',
    'watertank_tax_current',
    'watertank_tax_arrear',
  ];

  void _recalculatePropertyTax() {
    final road = _controllers['road_location_width']!.text.trim().toLowerCase();
    final nature = _controllers['nature_of_house']!.text.trim().toLowerCase();
    final propType = _controllers['property_type']!.text.trim().toLowerCase();
    final useAs = _controllers['property_use_as']!.text.trim().toLowerCase();
    final yearStr = _controllers['construction_year']!.text.trim();

    // 1. Rate
    double? rate;
    if (road.isNotEmpty && nature.isNotEmpty) {
      for (final e in _kRateTable.entries) {
        if (road == e.key.toLowerCase()) { rate = e.value[nature]; break; }
      }
    }

    // 2. ARV
    double? arv;
    String formula = '';
    final res = _parseDoubleValue(_controllers['total_residential_area']!.text);
    final com = _parseDoubleValue(_controllers['total_commercial_area']!.text);
    final emp = _parseDoubleValue(_controllers['empty_area']!.text);

    if (rate != null) {
      if (propType == 'residential' && res != null) {
        arv = res * 12 * rate * 0.8;
        formula = '${_formatComputedNumber(res)} × 12 × ${_formatComputedNumber(rate)} × 0.8';
      } else if (propType == 'commercial' && com != null) {
        arv = com * 12 * rate * 3;
        formula = '${_formatComputedNumber(com)} × 12 × ${_formatComputedNumber(rate)} × 3';
      } else if (propType == 'open plot' && emp != null) {
        arv = emp * 12 * rate;
        formula = '${_formatComputedNumber(emp)} × 12 × ${_formatComputedNumber(rate)}';
      } else if (propType == 'mixed self' && (res != null || com != null)) {
        final ra = (res ?? 0) * 12 * rate * 0.8;
        final ca = (com ?? 0) * 12 * rate * 3;
        arv = ra + ca;
        formula = '(${_formatComputedNumber(res ?? 0)} × 12 × ${_formatComputedNumber(rate)} × 0.8)'
            ' + (${_formatComputedNumber(com ?? 0)} × 12 × ${_formatComputedNumber(rate)} × 3)';
      }
    }

    // 3. Year adjustment
    double? adj;
    String adjLabel = '';
    if (arv != null) {
      final year = int.tryParse(yearStr);
      final isSelf = useAs == 'residential self' || useAs == 'mixed self';
      final isRented = useAs == 'residential rented' ||
          useAs == 'commercial rented' || useAs == 'mixed rented';
      if (year != null && isSelf) {
        if (year >= 2017) { adj = arv * 0.75; adjLabel = '− 25% discount (2017–2026)'; }
        else if (year >= 2007) { adj = arv * 0.675; adjLabel = '− 32.5% discount (2007–2016)'; }
        else { adj = arv * 0.60; adjLabel = '− 40% discount (before 2007)'; }
      } else if (year != null && isRented) {
        if (year >= 2017) { adj = arv * 1.25; adjLabel = '+ 25% addition (2017–2026)'; }
        else if (year >= 2007) { adj = arv * 1.125; adjLabel = '+ 12.5% addition (2007–2016)'; }
        else { adj = arv; adjLabel = 'No addition (before 2007)'; }
      }
    }

    // 4. Final ARV = adjusted if available, else raw arv
    final finalArv = adj ?? arv;

    // 5. Derived tax fields
    final houseTaxCurrent = finalArv != null ? finalArv * 0.1 : null;
    final waterTaxCurrent = finalArv != null ? finalArv * 0.1 : null;
    final houseTaxArrear = _parseDoubleValue(_controllers['house_tax_arrear']!.text) ?? 0.0;
    final houseTaxInterest = houseTaxArrear * 0.1;
    final waterTaxArrear = _parseDoubleValue(_controllers['water_tax_arrear']!.text) ?? 0.0;
    final waterTaxInterest = waterTaxArrear * 0.1;
    final totalHouseTax = houseTaxCurrent != null
        ? houseTaxCurrent + houseTaxArrear + houseTaxInterest
        : null;
    final totalWaterTax = waterTaxCurrent != null
        ? waterTaxCurrent + waterTaxArrear + waterTaxInterest
        : null;


    final isWatertankPresent = _controllers['watertank_present']!.text.toLowerCase() == 'true';
    final watertankTaxCurrent = _parseDoubleValue(_controllers['watertank_tax_current']!.text) ?? 0.0;
    final watertankTaxArrear = _parseDoubleValue(_controllers['watertank_tax_arrear']!.text) ?? 0.0;
    const watertankTaxInterest = 0.0;
    final totalWatertankTax = watertankTaxCurrent + watertankTaxArrear + watertankTaxInterest;

    final totalTax = (totalHouseTax ?? 0.0) +
        (totalWaterTax ?? 0.0) +
        (isWatertankPresent ? totalWatertankTax : 0.0);

    // 6. Write back to controllers (only if changed to avoid re-entrant loops)
    final rateStr = rate != null ? _formatComputedNumber(rate) : '';
    if (_controllers['rate']!.text != rateStr) _controllers['rate']!.text = rateStr;

    final arvStr = finalArv != null ? _formatComputedNumber(finalArv) : '';
    if (_controllers['total_current_arv']!.text != arvStr) {
      _controllers['total_current_arv']!.text = arvStr;
    }

    void _writeIfChanged(String key, double? val) {
      final s = val != null ? _formatComputedNumber(val) : '';
      if (_controllers[key]!.text != s) _controllers[key]!.text = s;
    }
    _writeIfChanged('house_tax_current', houseTaxCurrent);
    _writeIfChanged('water_tax_current', waterTaxCurrent);
    _writeIfChanged('house_tax_interest', houseTaxInterest);
    _writeIfChanged('water_tax_interest', waterTaxInterest);
    _writeIfChanged('total_house_tax', totalHouseTax);
    _writeIfChanged('total_water_tax', totalWaterTax);
    _writeIfChanged('watertank_tax_interest', watertankTaxInterest);
    _writeIfChanged('total_watertank_tax', totalWatertankTax);
    _writeIfChanged('total_tax', totalTax);

    if (mounted) {
      setState(() {
        _computedRate = rate;
        _computedArv = arv;
        _computedAdjustedArv = adj;
        _computedAdjLabel = adjLabel;
        _computedArvFormula = formula;
      });
    }
  }

  void _onSearchFieldsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchAutoFillLocationData() async {
    setState(() => _isLoadingLocationInfo = true);
    
    // Auto-fill exactly first district and its first ULB
    final districtList = await LocationService.getDistricts();
    if (districtList.isNotEmpty) {
      final firstDistrict = districtList.first;
      final districtId = firstDistrict['id']?.toString() ?? firstDistrict['district_id']?.toString() ?? '1';
      final districtName = firstDistrict['district_name']?.toString() ?? districtId;
      
      _selectedDistrictId = districtId;
      _controllers['district_id']!.text = districtName;

      final ulbList = await LocationService.getUlbs(districtId);
      if (ulbList.isNotEmpty) {
        final firstUlb = ulbList.first;
        final ulbId = firstUlb['id']?.toString() ?? firstUlb['ulb_id']?.toString() ?? '1';
        final ulbName = firstUlb['ulb_name']?.toString() ?? firstUlb['name']?.toString() ?? ulbId;

        _selectedUlbId = ulbId;
        _controllers['ulb_id']!.text = ulbName;
        
        // Fetch wards for the selected ULB
        _wardsList = await LocationService.getWards(ulbId);
      }
    }

    if (mounted) {
      setState(() => _isLoadingLocationInfo = false);
    }
  }

  Future<void> _fetchMohallas(String wardId) async {
    setState(() => _isLoadingLocationInfo = true);
    _selectedMohallaId = null;
    _controllers['mohalla_id']!.clear();
    
    _mohallasList = await LocationService.getMohallas(wardId);
    
    if (mounted) {
      setState(() => _isLoadingLocationInfo = false);
    }
  }

  Future<void> _refreshCurrentLocation() async {
    if (_isRefreshingLocation) return;

    setState(() => _isRefreshingLocation = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable device location services to autofill coordinates.'),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _centerPosition = LatLng(position.latitude, position.longitude);
        _latController.text = position.latitude.toStringAsFixed(6);
        _lngController.text = position.longitude.toStringAsFixed(6);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_showMap) return;
        try {
          _mapController.move(_centerPosition, _focusedMapZoom);
        } catch (_) {}
      });
    } catch (_) {}
    finally {
      if (mounted) {
        setState(() => _isRefreshingLocation = false);
      }
    }
  }

  void _toggleMapVisibility() {
    setState(() => _showMap = !_showMap);

    if (!_showMap) return;

    _fetchExistingMapLocations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _mapController.move(_centerPosition, _focusedMapZoom);
      } catch (_) {}
    });
  }

  bool get _canSearchExistingProperty {
    return _selectedWardId != null &&
      _controllers['old_house_no']!.text.trim().isNotEmpty;
  }

  void _fillController(String key, dynamic value) {
    final controller = _controllers[key];
    if (controller == null) return;
    controller.text = value?.toString() ?? '';
  }

  void _returnToFirstStep() {
    setState(() {
      _currentStep = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_formScrollController.hasClients) return;
      _formScrollController.jumpTo(0);
    });
  }

  int? get _currentUserId => _parseIntValue(widget.user['id']);

  void _clearSearchLoadedFields() {
    const fieldsToClear = [
      'old_ward_no',
      'old_ward_name',
      'old_moholla_name',
      'old_owner_name',
      'old_father_husband_name',
      'old_house_tax',
      'old_house_tax_arrear',
      'house_tax_arrear_2025_26',
      'old_water_tax',
      'water_tax_arrear_2025_26',
      'new_house_no',
      'owner_name',
      'father_husband_name',
      'mobile_no',
      'address',
      'road_location_width',
      'rate',
      'nature_of_house',
      'property_type',
      'property_use_as',
      'construction_year',
      'rebate_type',
      'financial_year',
      'front_feet',
      'depth_feet',
      'total_plot_area_sqft',
      'no_of_floors',
      'ground_floor_area',
      'first_floor_area',
      'second_floor_area',
      'third_floor_area',
      'total_residential_area',
      'total_commercial_area',
      'empty_area',
      'total_current_arv',
      'house_tax_current',
      'house_tax_arrear',
      'house_tax_interest',
      'total_house_tax',
      'water_tax_current',
      'water_tax_arrear',
      'water_tax_interest',
      'total_water_tax',
      'watertank_tax_current',
      'watertank_tax_arrear',
      'watertank_tax_interest',
      'total_watertank_tax',
      'total_tax',
      'remarks',
    ];

    for (final key in fieldsToClear) {
      _controllers[key]?.clear();
    }
    _controllers['watertank_present']?.text = 'False';
    _isFromSearchOrHistory = false;

    _surveyPhoto = null;
    _streetLightPhoto = null;
    _surveyPhotoUrl = null;
    _streetLightPhotoUrl = null;
    _currentSurveyId = null;
    _latController.clear();
    _lngController.clear();
    _centerPosition = const LatLng(29.4, 77.17);
  }

  Future<void> _resetSurveyForm() async {
    for (final controller in _controllers.values) {
      controller.clear();
    }

    _latController.clear();
    _lngController.clear();
    _surveyPhoto = null;
    _streetLightPhoto = null;
    _surveyPhotoUrl = null;
    _streetLightPhotoUrl = null;
    _selectedDistrictId = null;
    _selectedUlbId = null;
    _selectedWardId = null;
    _selectedMohallaId = null;
    _wardsList = [];
    _mohallasList = [];
    _currentSurveyId = null;
    _centerPosition = const LatLng(29.4, 77.17);
    _showMap = false;
    _showCustomTiles = true;
    _existingLocations = [];
    _isFromSearchOrHistory = false;
    _controllers['watertank_present']?.text = 'False';
    _currentStep = 0;

    if (mounted) {
      setState(() {});
    }

    await _fetchAutoFillLocationData();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_formScrollController.hasClients) {
        _formScrollController.jumpTo(0);
      }
    });
  }

  Future<void> _promptClearSurveyForm() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear current form?'),
          content: const Text(
            'This will clear the current survey data and start a fresh form. Your saved history will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    await _resetSurveyForm();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Form cleared. You can start a new survey.')),
    );
  }

  Future<void> _loadSurveyHistory({bool openDrawerAfterLoad = false}) async {
    final userId = _currentUserId;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History is unavailable for this user.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _historyError = null;
        _historyPage = 1;
        _hasMoreHistory = true;
        _surveyHistory = [];
      });
    }

    final history = await LocationService.getPropertySurveysByCreatedBy(
      userId,
      page: 1,
      limit: _historyPageSize,
    );

    if (!mounted) return;

    history.sort((left, right) {
      final leftDate = _historySortDate(left);
      final rightDate = _historySortDate(right);
      return rightDate.compareTo(leftDate);
    });

    setState(() {
      _surveyHistory = history;
      _historyPage = 1;
      _hasMoreHistory = history.length >= _historyPageSize;
      _isLoadingHistory = false;
      _historyError = history.isEmpty ? 'No surveys found for this surveyor.' : null;
    });

    if (openDrawerAfterLoad) {
      Scaffold.of(context).openDrawer();
    }
  }

  Future<void> _loadMoreHistory() async {
    final userId = _currentUserId;
    if (userId == null || _isLoadingMoreHistory || !_hasMoreHistory) return;

    if (mounted) setState(() => _isLoadingMoreHistory = true);

    final nextPage = _historyPage + 1;
    final more = await LocationService.getPropertySurveysByCreatedBy(
      userId,
      page: nextPage,
      limit: _historyPageSize,
    );

    if (!mounted) return;

    more.sort((left, right) {
      final leftDate = _historySortDate(left);
      final rightDate = _historySortDate(right);
      return rightDate.compareTo(leftDate);
    });

    setState(() {
      _surveyHistory = [..._surveyHistory, ...more];
      _historyPage = nextPage;
      _hasMoreHistory = more.length >= _historyPageSize;
      _isLoadingMoreHistory = false;
    });
  }

  String _historyValue(Map<String, dynamic> record, List<String> keys, {String fallback = '-'}) {
    for (final key in keys) {
      final value = record[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  String _historySubtitle(Map<String, dynamic> record) {
    final owner = _historyValue(record, ['owner_name', 'old_owner_name']);
    final houseNo = _historyValue(record, ['old_house_no', 'new_house_no']);
    final ward = _historyValue(record, ['ward_no', 'ward_id']);
    final mohalla = _historyValue(record, ['mohalla_name', 'old_moholla_name']);
    return 'House $houseNo • Ward $ward • $mohalla • $owner';
  }

  DateTime _historySortDate(Map<String, dynamic> record) {
    final rawValue = _historyValue(
      record,
      ['updated_at', 'created_at'],
      fallback: '',
    );
    return DateTime.tryParse(rawValue) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<Map<String, dynamic>> get _filteredSurveyHistory {
    final query = _historySearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _surveyHistory;

    return _surveyHistory.where((record) {
      final searchBlob = <String>[
        _historyValue(record, ['id', 'survey_id']),
        _historyValue(record, ['owner_name', 'old_owner_name']),
        _historyValue(record, ['old_house_no', 'new_house_no']),
        _historyValue(record, ['ward_no', 'ward_name', 'ward_id']),
        _historyValue(record, ['mohalla_name', 'old_moholla_name']),
        _historyValue(record, ['address']),
      ].join(' ').toLowerCase();
      return searchBlob.contains(query);
    }).toList();
  }

  Future<void> _openHistorySurvey(Map<String, dynamic> record) async {
    Navigator.of(context).pop();

    final districtId = record['district_id']?.toString();
    final districtName = record['district_name']?.toString();
    final ulbId = record['ulb_id']?.toString();
    final ulbName = record['ulb_name']?.toString();
    final wardId = record['ward_id']?.toString();
    final selectedMohallaId = record['mohalla_id']?.toString();

    if (mounted) {
      setState(() => _isLoadingLocationInfo = true);
    }

    final wardsList =
        ulbId != null && ulbId.isNotEmpty
            ? await LocationService.getWards(ulbId)
            : _wardsList;
    final mohallasList =
        wardId != null && wardId.isNotEmpty
            ? await LocationService.getMohallas(wardId)
            : _mohallasList;

    if (!mounted) return;

    setState(() {
      _clearSearchLoadedFields();
      _isFromSearchOrHistory = true;
      _applyPropertySurveyRecord(record);
      _currentStep = 1;
      _selectedDistrictId = districtId ?? _selectedDistrictId;
      _selectedUlbId = ulbId ?? _selectedUlbId;
      _selectedWardId = wardId;
      _selectedMohallaId = selectedMohallaId;
      _wardsList = wardsList;
      _mohallasList = mohallasList;
      if (districtName != null && districtName.isNotEmpty) {
        _controllers['district_id']!.text = districtName;
      }
      if (ulbName != null && ulbName.isNotEmpty) {
        _controllers['ulb_id']!.text = ulbName;
      }
      if (wardId != null && wardId.isNotEmpty) {
        _controllers['ward_id']!.text = wardId;
      }
      if (selectedMohallaId != null && selectedMohallaId.isNotEmpty) {
        _controllers['mohalla_id']!.text = selectedMohallaId;
      }
      _isLoadingLocationInfo = false;
    });

    _fetchExistingMapLocations();

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_formScrollController.hasClients) {
        _formScrollController.jumpTo(0);
      }
    });
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B5BDB), Color(0xFF5C7CFA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Survey History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _loadSurveyHistory(),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Refresh history',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _historySearchController,
                    decoration: InputDecoration(
                      hintText: 'Search history by house, owner, ward, mohalla',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 2),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent first',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_surveyHistory.isNotEmpty)
                        Text(
                          '${_filteredSurveyHistory.length}/${_surveyHistory.length} shown',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child:
                    _isLoadingHistory
                        ? const Center(child: CircularProgressIndicator())
                        : _historyError != null && _surveyHistory.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.inbox_outlined,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _historyError!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _loadSurveyHistory(),
                                child: ListView.separated(
                                  controller: _historyScrollController,
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _filteredSurveyHistory.length + (_hasMoreHistory ? 1 : 0),
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    // Loading footer at the end
                                    if (index == _filteredSurveyHistory.length) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                          child: _isLoadingMoreHistory
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                                )
                                              : TextButton(
                                                  onPressed: _loadMoreHistory,
                                                  child: const Text('Load more'),
                                                ),
                                        ),
                                      );
                                    }
                                    final record = _filteredSurveyHistory[index];
                                    final surveyId = _historyValue(record, ['id', 'survey_id']);
                                    final updatedAt = _historyValue(record, ['updated_at', 'created_at']);
                                    return Card(
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _openHistorySurvey(record),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 18,
                                                    backgroundColor: const Color(0xFFE8EAFF),
                                                    child: Text(
                                                      surveyId,
                                                      style: const TextStyle(
                                                        color: Color(0xFF3B5BDB),
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Text(
                                                      _historyValue(record, ['owner_name', 'old_owner_name', 'new_house_no', 'old_house_no']),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  TextButton.icon(
                                                    onPressed: () => _openHistorySurvey(record),
                                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                                    label: const Text('Edit'),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _historySubtitle(record),
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Updated: $updatedAt',
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 11.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString().trim());
  }

  double? _parseDoubleValue(String value) {
    final trimmedValue = value.trim();
    if (trimmedValue.isEmpty) return null;
    return double.tryParse(trimmedValue);
  }

  String? _textOrNull(String value) {
    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? null : trimmedValue;
  }

  String _formatComputedNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  void _updateComputedAreaFields() {
    final frontFeet = _parseDoubleValue(_controllers['front_feet']!.text);
    final depthFeet = _parseDoubleValue(_controllers['depth_feet']!.text);
    final groundFloorArea = _parseDoubleValue(_controllers['ground_floor_area']!.text);
    final totalCommercialArea = _parseDoubleValue(_controllers['total_commercial_area']!.text);
    final firstFloorArea = _parseDoubleValue(_controllers['first_floor_area']!.text);
    final secondFloorArea = _parseDoubleValue(_controllers['second_floor_area']!.text);
    final thirdFloorArea = _parseDoubleValue(_controllers['third_floor_area']!.text);

    final computedPlotArea =
        (frontFeet != null && depthFeet != null) ? frontFeet * depthFeet : null;
    final hasEmptyAreaInputs = groundFloorArea != null || totalCommercialArea != null;
    final computedEmptyArea =
      computedPlotArea != null && hasEmptyAreaInputs
        ? computedPlotArea -
          (groundFloorArea ?? 0) -
          (totalCommercialArea ?? 0)
        : null;

    final residentialAreas = [
      groundFloorArea,
      firstFloorArea,
      secondFloorArea,
      thirdFloorArea,
    ].whereType<double>();
    final computedResidentialArea =
      residentialAreas.isEmpty ? null : residentialAreas.fold<double>(0, (sum, value) => sum + value);

    final computedPlotAreaText =
        computedPlotArea == null ? '' : _formatComputedNumber(computedPlotArea);
    final computedEmptyAreaText =
        computedEmptyArea == null ? '' : _formatComputedNumber(computedEmptyArea);
    final computedResidentialAreaText =
        computedResidentialArea == null ? '' : _formatComputedNumber(computedResidentialArea);

    if (_controllers['total_plot_area_sqft']!.text != computedPlotAreaText) {
      _controllers['total_plot_area_sqft']!.text = computedPlotAreaText;
    }

    if (_controllers['total_residential_area']!.text != computedResidentialAreaText) {
      _controllers['total_residential_area']!.text = computedResidentialAreaText;
    }

    if (_controllers['empty_area']!.text != computedEmptyAreaText) {
      _controllers['empty_area']!.text = computedEmptyAreaText;
    }
  }

  Map<String, dynamic> _buildPropertySurveyPayload({
    String? photoGpsPath,
    String? streetLightPhotoPath,
  }) {
    return {
      'district_id': _parseIntValue(_selectedDistrictId),
      'ulb_id': _parseIntValue(_selectedUlbId),
      'ward_id': _parseIntValue(_selectedWardId),
      'mohalla_id': _parseIntValue(_selectedMohallaId),
      'old_ward_no': _textOrNull(_controllers['old_ward_no']!.text),
      'old_ward_name': _textOrNull(_controllers['old_ward_name']!.text),
      'old_moholla_name': _textOrNull(_controllers['old_moholla_name']!.text),
      'old_house_no': _textOrNull(_controllers['old_house_no']!.text),
      'old_owner_name': _textOrNull(_controllers['old_owner_name']!.text),
      'old_father_husband_name':
          _textOrNull(_controllers['old_father_husband_name']!.text),
      'old_house_tax': _parseDoubleValue(_controllers['old_house_tax']!.text),
      'old_house_tax_arrear':
          _parseDoubleValue(_controllers['old_house_tax_arrear']!.text),
      'house_tax_arrear_2025_26':
          _parseDoubleValue(_controllers['house_tax_arrear_2025_26']!.text),
      'old_water_tax': _parseDoubleValue(_controllers['old_water_tax']!.text),
      'water_tax_arrear_2025_26':
          _parseDoubleValue(_controllers['water_tax_arrear_2025_26']!.text),
      'new_house_no': _textOrNull(_controllers['new_house_no']!.text),
      'owner_name': _textOrNull(_controllers['owner_name']!.text),
      'father_husband_name': _textOrNull(_controllers['father_husband_name']!.text),
      'mobile_no': _textOrNull(_controllers['mobile_no']!.text),
      'address': _textOrNull(_controllers['address']!.text),
      'road_location_width': _textOrNull(_controllers['road_location_width']!.text),
      'rate': _parseDoubleValue(_controllers['rate']!.text),
      'nature_of_house': _textOrNull(_controllers['nature_of_house']!.text),
      'property_type': _textOrNull(_controllers['property_type']!.text),
      'property_use_as': _textOrNull(_controllers['property_use_as']!.text),
      'construction_year': _parseIntValue(_controllers['construction_year']!.text),
      'rebate_type': _textOrNull(_controllers['rebate_type']!.text),
      'financial_year': _textOrNull(_controllers['financial_year']!.text),
      'front_feet': _parseDoubleValue(_controllers['front_feet']!.text),
      'depth_feet': _parseDoubleValue(_controllers['depth_feet']!.text),
      'total_plot_area_sqft':
          _parseDoubleValue(_controllers['total_plot_area_sqft']!.text),
      'no_of_floors': _parseIntValue(_controllers['no_of_floors']!.text),
      'ground_floor_area': _parseDoubleValue(_controllers['ground_floor_area']!.text),
      'first_floor_area': _parseDoubleValue(_controllers['first_floor_area']!.text),
      'second_floor_area': _parseDoubleValue(_controllers['second_floor_area']!.text),
      'third_floor_area': _parseDoubleValue(_controllers['third_floor_area']!.text),
      'total_residential_area':
          _parseDoubleValue(_controllers['total_residential_area']!.text),
      'total_commercial_area':
          _parseDoubleValue(_controllers['total_commercial_area']!.text),
      'empty_area': _parseDoubleValue(_controllers['empty_area']!.text),
      'total_current_arv': _parseDoubleValue(_controllers['total_current_arv']!.text),
      'house_tax_current': _parseDoubleValue(_controllers['house_tax_current']!.text),
      'house_tax_arrear': _parseDoubleValue(_controllers['house_tax_arrear']!.text),
      'house_tax_interest': _parseDoubleValue(_controllers['house_tax_interest']!.text),
      'total_house_tax': _parseDoubleValue(_controllers['total_house_tax']!.text),
      'water_tax_current': _parseDoubleValue(_controllers['water_tax_current']!.text),
      'water_tax_arrear': _parseDoubleValue(_controllers['water_tax_arrear']!.text),
      'water_tax_interest': _parseDoubleValue(_controllers['water_tax_interest']!.text),
      'total_water_tax': _parseDoubleValue(_controllers['total_water_tax']!.text),
      'watertank_present': _controllers['watertank_present']!.text.toLowerCase() == 'true',
      'watertank_tax_current': _controllers['watertank_present']!.text.toLowerCase() == 'true'
          ? _parseDoubleValue(_controllers['watertank_tax_current']!.text)
          : 0.0,
      'watertank_tax_arrear': _controllers['watertank_present']!.text.toLowerCase() == 'true'
          ? _parseDoubleValue(_controllers['watertank_tax_arrear']!.text)
          : 0.0,
      'watertank_tax_interest': _controllers['watertank_present']!.text.toLowerCase() == 'true'
          ? _parseDoubleValue(_controllers['watertank_tax_interest']!.text)
          : 0.0,
      'total_watertank_tax': _controllers['watertank_present']!.text.toLowerCase() == 'true'
          ? _parseDoubleValue(_controllers['total_watertank_tax']!.text)
          : 0.0,
      'total_tax': _parseDoubleValue(_controllers['total_tax']!.text),
      'photo_gps': photoGpsPath,
      'street_light_photo': streetLightPhotoPath,
      'gps_location':
          '${_latController.text.trim()},${_lngController.text.trim()}',
      'remarks': _textOrNull(_controllers['remarks']!.text),
      'created_by': _parseIntValue(widget.user['id']),
    };
  }

  Future<String?> _uploadSurveyImage(File? imageFile) async {
    if (imageFile == null) return null;
    return LocationService.uploadSurveyImage(imageFile);
  }

  void _applyPropertySurveyRecord(Map<String, dynamic> record) {
    _fillController('district_id', record['district_name'] ?? record['district_id']);
    _fillController('ulb_id', record['ulb_name'] ?? record['ulb_id']);
    _fillController('ward_id', record['ward_id'] ?? record['ward_no']);
    _fillController('mohalla_id', record['mohalla_id'] ?? record['mohalla_name']);

    _fillController('old_ward_no', record['ward_no'] ?? record['old_ward_no']);
    _fillController('old_ward_name', record['ward_name'] ?? record['old_ward_name'] ?? record['ward_no']);
    _fillController('old_moholla_name', record['mohalla_name'] ?? record['old_moholla_name']);
    _fillController('old_house_no', record['old_house_no'] ?? record['house_no']);
    _fillController('old_owner_name', record['old_owner_name']);
    _fillController('old_father_husband_name', record['old_father_husband_name']);
    _fillController('old_house_tax', record['old_house_tax']);
    _fillController('old_house_tax_arrear', record['old_house_tax_arrear']);
    _fillController('house_tax_arrear_2025_26', record['house_tax_arrear_2025_26']);
    _fillController('old_water_tax', record['old_water_tax']);
    _fillController('water_tax_arrear_2025_26', record['water_tax_arrear_2025_26']);

    _fillController('new_house_no', record['new_house_no']);
    _fillController('owner_name', record['owner_name']);
    _fillController('father_husband_name', record['father_husband_name']);
    _fillController('mobile_no', record['mobile_no']);
    _fillController('address', record['address']);
    _fillController('road_location_width', record['road_location_width']);
    _fillController('rate', record['rate']);
    _fillController('nature_of_house', record['nature_of_house']);
    _fillController('property_type', record['property_type']);
    _fillController('property_use_as', record['property_use_as']);
    _fillController('construction_year', record['construction_year']);
    _fillController('rebate_type', record['rebate_type']);
    _fillController('financial_year', record['financial_year']);

    _fillController('front_feet', record['front_feet']);
    _fillController('depth_feet', record['depth_feet']);
    _fillController('total_plot_area_sqft', record['total_plot_area_sqft']);
    _fillController('no_of_floors', record['no_of_floors']);
    _fillController('ground_floor_area', record['ground_floor_area']);
    _fillController('first_floor_area', record['first_floor_area']);
    _fillController('second_floor_area', record['second_floor_area']);
    _fillController('third_floor_area', record['third_floor_area']);
    _fillController('total_residential_area', record['total_residential_area']);
    _fillController('total_commercial_area', record['total_commercial_area']);
    _fillController('empty_area', record['empty_area']);

    _fillController('total_current_arv', record['total_current_arv']);
    _fillController('house_tax_current', record['house_tax_current']);
    _fillController('house_tax_arrear', record['house_tax_arrear']);
    _fillController('house_tax_interest', record['house_tax_interest']);
    _fillController('total_house_tax', record['total_house_tax']);
    _fillController('water_tax_current', record['water_tax_current']);
    _fillController('water_tax_arrear', record['water_tax_arrear']);
    _fillController('water_tax_interest', record['water_tax_interest']);
    _fillController('total_water_tax', record['total_water_tax']);
    if (record['watertank_present'] != null) {
      _fillController(
        'watertank_present',
        record['watertank_present'] == true ? 'True' : 'False',
      );
    } else {
      _fillController('watertank_present', 'False');
    }
    _fillController('watertank_tax_current', record['watertank_tax_current']);
    _fillController('watertank_tax_arrear', record['watertank_tax_arrear']);
    _fillController('watertank_tax_interest', record['watertank_tax_interest']);
    _fillController('total_watertank_tax', record['total_watertank_tax']);
    _fillController('total_tax', record['total_tax']);
    _fillController('remarks', record['remarks']);

    _currentSurveyId =
      _parseIntValue(record['id'] ?? record['survey_id']) ?? _currentSurveyId;

    _surveyPhotoUrl = record['photo_gps']?.toString();
    _streetLightPhotoUrl = record['street_light_photo']?.toString();

    final gpsLocation = record['gps_location']?.toString();
    if (gpsLocation != null && gpsLocation.contains(',')) {
      final parts = gpsLocation.split(',');
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          _centerPosition = LatLng(lat, lng);
          _latController.text = lat.toStringAsFixed(6);
          _lngController.text = lng.toStringAsFixed(6);
        }
      }
    }

    _selectedWardId = record['ward_id']?.toString() ?? _selectedWardId;
    _selectedMohallaId = record['mohalla_id']?.toString() ?? _selectedMohallaId;
  }

  Future<void> _searchExistingProperty() async {
    if (!_canSearchExistingProperty || _isSearchingProperty) return;

    setState(() => _isSearchingProperty = true);

    final wardNo = (_selectedWardId ?? '').trim();

    final record = await LocationService.searchPropertySurvey(
      wardNo: wardNo,
      houseNo: _controllers['old_house_no']!.text.trim(),
      mohallaName: _controllers['old_moholla_name']!.text.trim(),
      page: 1,
      limit: 20,
    );

    if (!mounted) return;

    setState(() => _isSearchingProperty = false);
    if (record == null) {
      setState(() {
        _clearSearchLoadedFields();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.search_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('No property survey found for these details.'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // If the search service returned an API message (e.g. "Record already completed"), show it.
    if (record.containsKey('__api_message')) {
      final msg = record['__api_message']?.toString() ?? 'No property survey found for these details.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(msg),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isFromSearchOrHistory = true;
      _applyPropertySurveyRecord(record);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Property survey data loaded.'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _nextStep() {
    if (_isSubmitting) return;

    if (_formKey.currentState?.validate() ?? false) {
      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        _handleSubmit();
      }
    }
  }

  void _previousStep() {
    if (_isSubmitting) return;

    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  void dispose() {
    for (final key in ['old_ward_no', 'old_moholla_name', 'old_house_no']) {
      _controllers[key]!.removeListener(_onSearchFieldsChanged);
    }
    for (final key in ['front_feet', 'depth_feet', 'ground_floor_area', 'total_commercial_area']) {
      _controllers[key]!.removeListener(_updateComputedAreaFields);
    }
    for (final key in _kTaxListenerKeys) {
      _controllers[key]!.removeListener(_recalculatePropertyTax);
    }
    _historySearchController.removeListener(_onSearchFieldsChanged);
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _latController.dispose();
    _lngController.dispose();
    _formScrollController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  void _updateCoordinates(LatLng position) {
    setState(() {
      _centerPosition = position;
      _latController.text = position.latitude.toStringAsFixed(6);
      _lngController.text = position.longitude.toStringAsFixed(6);
    });
  }

  void _confirmLocation() {
    setState(() => _showMap = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Location set: ${_centerPosition.latitude.toStringAsFixed(5)}, '
              '${_centerPosition.longitude.toStringAsFixed(5)}',
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3B5BDB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Map<String, dynamic>> _existingLocations = [];

  Future<void> _fetchExistingMapLocations() async {
    final wardId = _selectedWardId;
    if (wardId == null || wardId.isEmpty) {
      if (mounted) {
        setState(() {
          _existingLocations = [];
        });
      }
      return;
    }

    try {
      final locations = await LocationService.getMapPropertySurveys(wardId: wardId);
      if (mounted) {
        setState(() {
          _existingLocations = locations;
        });
      }
    } catch (_) {}
  }

  void _handleSubmit() {
    _submitSurvey();
  }

  Future<void> _submitSurvey() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Please select a location on the map.'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final surveyPhotoPath = await _uploadSurveyImage(_surveyPhoto);
      if (_surveyPhoto != null && surveyPhotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Failed to upload survey photo.'),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final streetLightPhotoPath = await _uploadSurveyImage(_streetLightPhoto);
      if (_streetLightPhoto != null && streetLightPhotoPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Failed to upload street light photo.'),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      final isUpdate = _currentSurveyId != null;
      final payload = _buildPropertySurveyPayload(
        photoGpsPath: surveyPhotoPath ?? (isUpdate ? _surveyPhotoUrl : null),
        streetLightPhotoPath: streetLightPhotoPath ?? (isUpdate ? _streetLightPhotoUrl : null),
      );

      final result = isUpdate
          ? await LocationService.updatePropertySurvey(_currentSurveyId!, payload)
          : await LocationService.createPropertySurvey(payload);

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Failed to save property survey.'),
              ],
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      if (result.containsKey('__api_message')) {
        final message = result['__api_message']?.toString() ?? 'Duplicate survey already exists.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      if (!isUpdate) {
        _currentSurveyId = _parseIntValue(result['id'] ?? result['survey_id']) ?? _currentSurveyId;
      }

      await _resetSurveyForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(isUpdate ? 'Property survey updated successfully!' : 'Property survey created successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _ProfileSheet(
            user: widget.user,
            onLogout: () async {
              Navigator.of(context).pop();
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

  Widget _buildPhotosSection() {
    return _SectionCard(
      title: 'Photos',
      icon: Icons.photo_camera_outlined,
      children: [
        const Text(
          'Photo (GPS)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ImagePickerWidget(
          image: _surveyPhoto,
          imageUrl: _surveyPhotoUrl,
          onImageChanged: (f) => setState(() => _surveyPhoto = f),
          onRemoveImageUrl: () => setState(() => _surveyPhotoUrl = null),
        ),
        const SizedBox(height: 16),
        const Text(
          'Street Light Photo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ImagePickerWidget(
          image: _streetLightPhoto,
          imageUrl: _streetLightPhotoUrl,
          onImageChanged: (f) => setState(() => _streetLightPhoto = f),
          onRemoveImageUrl: () => setState(() => _streetLightPhotoUrl = null),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return IconButton(
      tooltip: 'Search existing property',
      icon: _isSearchingProperty
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search),
      color: const Color(0xFF3B5BDB),
      onPressed:
          _canSearchExistingProperty && !_isSearchingProperty
              ? _searchExistingProperty
              : null,
    );
  }

  Widget _buildMapSection() {
    return _SectionCard(
      title: 'Location',
      icon: Icons.place_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: _CoordField(controller: _latController, label: 'Latitude'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CoordField(
                controller: _lngController,
                label: 'Longitude',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            icon: Icon(
              _showMap
                  ? Icons.keyboard_arrow_up
                  : Icons.add_location_alt_outlined,
              size: 20,
            ),
            label: Text(
              _showMap ? 'Hide Map' : 'Select Location on Map',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _showMap ? Colors.grey.shade600 : const Color(0xFF3B5BDB),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _toggleMapVisibility,
          ),
        ),
        if (_showMap) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 340,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _centerPosition,
                      initialZoom: _focusedMapZoom,
                      minZoom: 4.0,
                      maxZoom: 22.0,
                      onPositionChanged: (MapCamera camera, bool hasGesture) {
                        if (hasGesture) {
                          _updateCoordinates(camera.center);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                        subdomains: const ['0', '1', '2', '3'],
                        userAgentPackageName: 'com.example.app',
                        maxZoom: 22,
                      ),
                      if (_showCustomTiles)
                        TileLayer(
                          urlTemplate:
                              'https://cdn.skyjumper.in/skykids/tiles/{z}/{x}/{y}.jpg',
                          userAgentPackageName: 'com.example.app',
                          errorTileCallback: (_, __, ___) {},
                        ),
                      MarkerLayer(
                        markers: _existingLocations
                            .map((loc) {
                              final lat = double.tryParse(loc['latitude']?.toString() ?? '');
                              final lng = double.tryParse(loc['longitude']?.toString() ?? '');
                              if (lat == null || lng == null) return null;
                              return Marker(
                                point: LatLng(lat, lng),
                                width: 16,
                                height: 16,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(50),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })
                            .whereType<Marker>()
                            .toList(),
                      ),
                    ],
                  ),
                  const IgnorePointer(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 36),
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.yellow,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: _MapControls(
                      showCustomTiles: _showCustomTiles,
                      onCustomTilesToggle:
                          () => setState(
                            () => _showCustomTiles = !_showCustomTiles,
                          ),
                    ),
                  ),
                  Positioned(
                    top: 66,
                    right: 10,
                    child: Material(
                      color: Colors.white,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Refresh location',
                        onPressed:
                            _isRefreshingLocation ? null : _refreshCurrentLocation,
                        icon: _isRefreshingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Color(0xFF3B5BDB),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          'Confirm This Location',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B5BDB),
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _confirmLocation,
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildHistoryDrawer(),
      backgroundColor: const Color(0xFFF0F2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3B5BDB),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open survey history',
            onPressed: () async {
              await _loadSurveyHistory();
              if (!mounted) return;
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const Text(
          'Survey Entry',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear current form',
            onPressed: _promptClearSurveyForm,
          ),
          GestureDetector(
            onTap: _showProfileSheet,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Text(
                  (widget.user['name'] as String? ?? 'S')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isSubmitting,
              child: Column(
                children: [
                  // ── Progress Indicator ───────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    color: Colors.white,
                    child: Row(
                      children: List.generate(_totalSteps, (index) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  index <= _currentStep
                                      ? const Color(0xFF3B5BDB)
                                      : const Color(0xFFE8EAFF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      controller: _formScrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        SurveyFormContent(
                          currentStep: _currentStep,
                          controllers: _controllers,
                          mapWidget: _buildMapSection(),
                          photosWidget: _buildPhotosSection(),
                          searchButton: _buildSearchButton(),
                          taxCalculatorWidget: PropertyTaxCalculatorWidget(
                            rate: _computedRate,
                            totalCurrentArv: _computedArv,
                            adjustedArv: _computedAdjustedArv,
                            adjustmentLabel: _computedAdjLabel,
                            arvFormula: _computedArvFormula,
                            roadLocationText: _controllers['road_location_width']!.text,
                            natureOfHouseText: _controllers['nature_of_house']!.text,
                          ),
                          wardsList: _wardsList,
                          mohallasList: _mohallasList,
                          selectedWardId: _selectedWardId,
                          selectedMohallaId: _selectedMohallaId,
                          onWardChanged: (wardId) {
                            setState(() {
                              _selectedWardId = wardId;
                              _controllers['ward_id']!.text = wardId ?? '';
                            });
                            if (wardId != null) {
                              _fetchMohallas(wardId);
                              _fetchExistingMapLocations();
                            } else {
                              setState(() {
                                _existingLocations = [];
                              });
                            }
                          },
                          onMohallaChanged: (mohallaId) {
                            setState(() {
                              _selectedMohallaId = mohallaId;
                              _controllers['mohalla_id']!.text = mohallaId ?? '';
                            });
                          },
                          onRoadLocationChanged: (val) {
                            setState(() {
                              _controllers['road_location_width']!.text = val ?? '';
                            });
                          },
                          onNatureOfHouseChanged: (val) {
                            setState(() {
                              _controllers['nature_of_house']!.text = val ?? '';
                            });
                          },
                          onPropertyTypeChanged: (val) {
                            setState(() {
                              _controllers['property_type']!.text = val ?? '';
                            });
                          },
                          onPropertyUseAsChanged: (val) {
                            setState(() {
                              _controllers['property_use_as']!.text = val ?? '';
                            });
                          },
                          onWatertankPresentChanged: (val) {
                            setState(() {
                              _controllers['watertank_present']!.text = val ?? 'False';
                              if (val == 'True') {
                                if (_controllers['watertank_tax_current']!.text.isEmpty) {
                                  _controllers['watertank_tax_current']!.text = '600';
                                }
                              }
                            });
                            _recalculatePropertyTax();
                          },
                        ),

                        const SizedBox(height: 24),

                        // ── Navigation Buttons ───────────────────────────────────────────
                        Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                flex: 1,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    side: const BorderSide(color: Color(0xFF3B5BDB)),
                                  ),
                                  onPressed: _previousStep,
                                  child: const Text(
                                    'Previous',
                                    style: TextStyle(
                                      color: Color(0xFF3B5BDB),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentStep > 0) const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _currentStep == _totalSteps - 1
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFF3B5BDB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _nextStep,
                                child: _isSubmitting && _currentStep == _totalSteps - 1
                                    ? const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Submitting...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _currentStep == _totalSteps - 1
                                            ? 'Submit Survey'
                                            : 'Next Step',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.12),
                  child: const Center(
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Submitting survey...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ──────────────────────────────────────────────────────

@staticIconProvider
class SurveyFormContent extends StatelessWidget {
  final int currentStep;
  final Map<String, TextEditingController> controllers;
  final Widget mapWidget;
  final Widget photosWidget;
  final Widget? searchButton;
  final Widget? taxCalculatorWidget;

  final List<dynamic>? wardsList;
  final List<dynamic>? mohallasList;
  final String? selectedWardId;
  final String? selectedMohallaId;
  final ValueChanged<String?>? onWardChanged;
  final ValueChanged<String?>? onMohallaChanged;
  final ValueChanged<String?>? onRoadLocationChanged;
  final ValueChanged<String?>? onNatureOfHouseChanged;
  final ValueChanged<String?>? onPropertyTypeChanged;
  final ValueChanged<String?>? onPropertyUseAsChanged;
  final ValueChanged<String?>? onWatertankPresentChanged;

  const SurveyFormContent({
    super.key,
    required this.currentStep,
    required this.controllers,
    required this.mapWidget,
    required this.photosWidget,
    this.searchButton,
    this.taxCalculatorWidget,
    this.wardsList,
    this.mohallasList,
    this.selectedWardId,
    this.selectedMohallaId,
    this.onWardChanged,
    this.onMohallaChanged,
    this.onRoadLocationChanged,
    this.onNatureOfHouseChanged,
    this.onPropertyTypeChanged,
    this.onPropertyUseAsChanged,
    this.onWatertankPresentChanged,
  });

  Widget _buildStringDropdown({
    required String key,
    required String label,
    required IconData icon,
    required List<String> options,
    ValueChanged<String?>? onChanged,
  }) {
    final current = controllers[key]?.text.trim();
    final value = (current != null && current.isNotEmpty) ? current : null;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Select $label',
            prefixIcon: Icon(icon, color: const Color(0xFF3B5BDB)),
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            labelStyle: const TextStyle(color: Color(0xFF3B5BDB)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
          items: options.map((o) => DropdownMenuItem<String>(value: o, child: Text(o))).toList(),
          onChanged: (val) {
            controllers[key]?.text = val ?? '';
            if (onChanged != null) onChanged(val);
          },
          validator: null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildField(
    String key,
    String label, {
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    return Column(
      children: [
        CustomTextField(
          controller: controllers[key]!,
          label: label,
          hint: 'Enter $label',
          prefixIcon: icon ?? Icons.edit_outlined,
          keyboardType: keyboardType,
          readOnly: readOnly,
          suffixIcon: suffixIcon,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<dynamic> items,
    required String idKey,
    required String displayKey,
    required ValueChanged<String?>? onChanged,
    bool requiredField = true,
  }) {
    final uniqueItems = <Map<String, dynamic>>[];
    final seenValues = <String>{};

    for (final item in items) {
      if (item is! Map) continue;
      final mappedItem = Map<String, dynamic>.from(item as Map);
      final itemValue = mappedItem[idKey]?.toString();
      if (itemValue == null || itemValue.isEmpty) continue;
      if (seenValues.add(itemValue)) {
        uniqueItems.add(mappedItem);
      }
    }

    final normalizedValue =
        value != null &&
                uniqueItems.where((item) => item[idKey]?.toString() == value).length == 1
            ? value
            : null;

    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: normalizedValue,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Select $label',
            prefixIcon: Icon(icon, color: const Color(0xFF3B5BDB)),
            filled: true,
            fillColor: const Color(0xFFF8F9FF),
            labelStyle: const TextStyle(color: Color(0xFF3B5BDB)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF3B5BDB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
          items: uniqueItems.map<DropdownMenuItem<String>>((item) {
            return DropdownMenuItem<String>(
              value: item[idKey]?.toString(),
              child: Text(item[displayKey]?.toString() ?? ''),
            );
          }).toList(),
          onChanged: onChanged,
          validator:
              requiredField
                  ? (val) => val == null ? 'Please select $label' : null
                  : null,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentStep == 0) {
      return _SectionCard(
        title: 'Location & Administration',
        icon: Icons.map_outlined,
        children: [
          _buildField(
            'district_id',
            'District Name',
            keyboardType: TextInputType.text,
            readOnly: true,
          ),
          _buildField(
            'ulb_id', 
            'ULB Name', 
            keyboardType: TextInputType.text,
            readOnly: true,
          ),
          _buildDropdownField(
            label: 'Ward Number',
            icon: Icons.edit_outlined,
            value: selectedWardId,
            items: wardsList ?? [],
            idKey: 'id',
            displayKey: 'ward_no',
            onChanged: onWardChanged,
          ),
          _buildDropdownField(
            label: 'Mohalla Name',
            icon: Icons.edit_outlined,
            value: selectedMohallaId,
            items: mohallasList ?? [],
            idKey: 'id',
            displayKey: 'mohalla_name',
            onChanged: onMohallaChanged,
            requiredField: false,
          ),
        ],
      );
    }

    if (currentStep == 1) {
      return _SectionCard(
        title: 'Old Property Details',
        icon: Icons.history_outlined,
        children: [
          _buildField('old_house_no','Old House No',suffixIcon: searchButton,),
          _buildField('old_ward_no', 'Old Ward No'),
          _buildField('old_ward_name', 'Old Ward Name'),
          _buildField('old_moholla_name', 'Old Mohalla Name'),
          _buildField(
            'old_owner_name',
            'Old Owner Name',
            icon: Icons.person_outline,
          ),
          _buildField('old_father_husband_name', 'Old Father/Husband Name'),
          _buildField(
            'old_house_tax',
            'Old House Tax',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'old_house_tax_arrear',
            'Old House Tax Arrear',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'house_tax_arrear_2025_26',
            'House Tax Arrear 2025-26',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'old_water_tax',
            'Old Water Tax',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'water_tax_arrear_2025_26',
            'Water Tax Arrear 2025-26',
            keyboardType: TextInputType.number,
          ),
        ],
      );
    }

    if (currentStep == 2) {
      return _SectionCard(
        title: 'New Property Details',
        icon: Icons.home_outlined,
        children: [
          _buildField('new_house_no', 'New House No'),
          _buildField('owner_name', 'Owner Name', icon: Icons.person_outline),
          _buildField('father_husband_name', 'Father/Husband Name'),
          _buildField(
            'mobile_no',
            'Mobile No',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
          ),
          _buildField('address', 'Address', icon: Icons.location_on_outlined),
          _buildStringDropdown(
            key: 'road_location_width',
            label: 'Road Location Width',
            icon: Icons.straighten_outlined,
            options: const [
              '3 -9 meter',
              '9 -12 meter',
              '12 -24 meter',
              '24 -more than  meter',
            ],
            onChanged: onRoadLocationChanged,
          ),
          _buildField('rate', 'Rate', keyboardType: TextInputType.number, readOnly: true),
          _buildStringDropdown(
            key: 'nature_of_house',
            label: 'Nature of House',
            icon: Icons.home_repair_service,
            options: const [
              'RCC &RBC pakka',
              'Semi Pakka',
              'Kachha',
              'Open Plot',
            ],
            onChanged: onNatureOfHouseChanged,
          ),
          _buildStringDropdown(
            key: 'property_type',
            label: 'Property Type',
            icon: Icons.domain,
            options: const [
              'Residential',
              'Commercial',
              'Mixed self',
              'Open Plot',
            ],
            onChanged: onPropertyTypeChanged,
          ),
          _buildStringDropdown(
            key: 'property_use_as',
            label: 'Property Use As',
            icon: Icons.work_outline,
            options: const [
              'Residential Self',
              'Residential rented',
              'Commercial Self',
              'Commercial Rented',
              'Mixed self',
              'Mixed Rented',
              'Open Plot',
              'Temple',
              'Govt Hospital',
              'Pvt hospital',
              'Govt school & college',
              'Pvt school & college',
              'Mosque',
              'Petrol Pump',
              'Hotel',
              'Park',
              'Dharamshala',
              'Cinema Ghar',
              'Bank',
              'Gos Godam',
              'Bus Stand',
              'Lic',
              'EceFactroy Kabristan',
              'Majar',
              'Pump Talab',
            ],
            onChanged: onPropertyUseAsChanged,
          ),
          _buildField(
            'construction_year',
            'Construction Year',
            keyboardType: TextInputType.number,
          ),
          _buildField('rebate_type', 'Rebate Type'),
          _buildField('financial_year', 'Financial Year'),
        ],
      );
    }

    if (currentStep == 3) {
      return _SectionCard(
        title: 'Area & Dimensions',
        icon: Icons.straighten_outlined,
        children: [
          _buildField(
            'front_feet',
            'Front (Feet)',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'depth_feet',
            'Depth (Feet)',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'total_plot_area_sqft',
            'Total Plot Area (Sq.Ft)',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'no_of_floors',
            'No. of Floors',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'ground_floor_area',
            'Ground Floor Area',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'first_floor_area',
            'First Floor Area',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'second_floor_area',
            'Second Floor Area',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'third_floor_area',
            'Third Floor Area',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'total_residential_area',
            'Total Residential Area',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'total_commercial_area',
            'Total Commercial Area',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'empty_area',
            'Empty Area',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
        ],
      );
    }

    if (currentStep == 4) {
      return _SectionCard(
        title: 'Taxes & Assessment',
        icon: Icons.request_quote_outlined,
        children: [
          if (taxCalculatorWidget != null) ...[taxCalculatorWidget!, const SizedBox(height: 16)],
          _buildField(
            'total_current_arv',
            'Total Current ARV',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'house_tax_current',
            'House Tax Current',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'house_tax_arrear',
            'House Tax Arrear',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'house_tax_interest',
            'House Tax Interest',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'total_house_tax',
            'Total House Tax',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'water_tax_current',
            'Water Tax Current',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'water_tax_arrear',
            'Water Tax Arrear',
            keyboardType: TextInputType.number,
          ),
          _buildField(
            'water_tax_interest',
            'Water Tax Interest',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildField(
            'total_water_tax',
            'Total Water Tax',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          _buildStringDropdown(
            key: 'watertank_present',
            label: 'Water Tank Present',
            icon: Icons.water_drop_outlined,
            options: const ['True', 'False'],
            onChanged: onWatertankPresentChanged,
          ),
          if (controllers['watertank_present']?.text.toLowerCase() == 'true') ...[
            _buildField(
              'watertank_tax_current',
              'Water Tank Tax Current',
              keyboardType: TextInputType.number,
            ),
            _buildField(
              'watertank_tax_arrear',
              'Water Tank Tax Arrear',
              keyboardType: TextInputType.number,
            ),
            _buildField(
              'watertank_tax_interest',
              'Water Tank Tax Interest',
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
            _buildField(
              'total_watertank_tax',
              'Total Water Tank Tax',
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
          ],
          _buildField(
            'total_tax',
            'Total Tax',
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
        ],
      );
    }

    if (currentStep == 5) {
      return Column(
        children: [
          photosWidget,
          const SizedBox(height: 12),
          mapWidget,
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Remarks',
            icon: Icons.note_outlined,
            children: [_buildField('remarks', 'Remarks', icon: Icons.notes)],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

@staticIconProvider
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3B5BDB)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 16, color: Color(0xFFE8EAFF)),
          ...children,
        ],
      ),
    );
  }
}

class _CoordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _CoordField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF3B5BDB)),
        filled: true,
        fillColor: const Color(0xFFF0F2FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCDD5F3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3B5BDB)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        hintText: '—',
        hintStyle: const TextStyle(color: Colors.black26),
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  const _ProfileSheet({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final name = user['name'] as String? ?? 'Surveyor';
    final mobile = user['mobile'] as String? ?? '';
    final role = (user['role'] as String? ?? 'surveyor').toUpperCase();
    final initials =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Avatar + gradient header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B5BDB), Color(0xFF74C0FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white24,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info rows + logout
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.phone_android,
                  label: 'Mobile',
                  value: mobile,
                ),
                const SizedBox(height: 12),
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: role,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onLogout,
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

@staticIconProvider
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAFF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3B5BDB)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControls extends StatelessWidget {
  final bool showCustomTiles;
  final VoidCallback onCustomTilesToggle;

  const _MapControls({
    required this.showCustomTiles,
    required this.onCustomTilesToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: showCustomTiles ? 'Hide drone image' : 'Show drone image',
        onPressed: onCustomTilesToggle,
        icon: Icon(
          showCustomTiles ? Icons.layers_clear : Icons.layers,
          color: const Color(0xFF3B5BDB),
        ),
      ),
    );
  }
}
