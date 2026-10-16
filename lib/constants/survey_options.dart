/// Dropdown / chip options for the survey form.
/// Edit these lists to match the values the backend expects.
class SurveyOptions {
  static const natureOfHouse = [
    'Pakka',
    'Semi Pakka',
    'Kachha',
    'Open Plot',
  ];

  static const widthOfRoadInFront = [
    'Less than 3 m',
    '3 - 9 m',
    '9 - 12 m',
    '12 - 24 m',
    'More than 24 m',
  ];

  static const typeOfConstruction = [
    'RCC',
    'RBC',
    'Tin / Asbestos Shed',
    'Mud / Kachha',
    'Other',
  ];

  static const useOfHouse = [
    'Residential',
    'Commercial',
    'Mixed',
    'Institutional',
    'Industrial',
    'Religious',
    'Government',
    'Vacant',
  ];

  /// Value of [useOfHouse] that reveals the "ifmixed" field.
  static const mixedUse = 'Mixed';

  /// Values of [useOfHouse] that reveal the "commercialArea" field.
  static const usesWithCommercialArea = {'Commercial', 'Mixed'};

  static const occupancyStatus = [
    'Self Occupied',
    'Rented',
    'Partially Rented',
    'Vacant',
  ];

  /// Index in this list = number of floors above ground.
  static const floorNo = ['Ground', 'G+1', 'G+2', 'G+3', 'G+4'];

  static const yesNo = ['Yes', 'No'];
}
